// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract PorkelonStakingRewards is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    IERC20Upgradeable public stakingToken;  // PORK token for staking
    IERC20Upgradeable public rewardsToken;  // PORK token for rewards (same as stakingToken)

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration;
    // Timestamp when rewards finish
    uint256 public finishAt;
    // Minimum of last updated time and reward finish time
    uint256 public updatedAt;
    // Reward to be paid out per second
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint256) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint256) public rewards;

    // Total staked
    uint256 public totalSupply;
    // User address => staked amount
    mapping(address => uint256) public balanceOf;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event RewardAdded(uint256 reward);

    // ====================== CUSTOM ERRORS (gas savings on reverts) ======================
    error CannotStakeZero();
    error CannotWithdrawZero();
    error InsufficientStakedBalance();
    error PreviousRewardsPeriodMustFinish();
    error RewardRateMustBePositive();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakingToken, address _rewardsToken) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        stakingToken = IERC20Upgradeable(_stakingToken);
        rewardsToken = IERC20Upgradeable(_rewardsToken);
        duration = 365 days;  // Default: 1 year; adjustable
    }

    // ====================== GAS-OPTIMIZED REWARD UPDATE (replaces modifier) ======================
    // - Computes rewardPerToken delta **once** per transaction
    // - Inlines earned() calculation → eliminates redundant rewardPerToken() call
    // - No function call overhead in hot path (stake/withdraw/getReward)
    function _updateReward(address account) internal {
        uint256 lastTime = lastTimeRewardApplicable();

        if (totalSupply != 0) {
            // Exact same math as original rewardPerToken() but computed only once
            uint256 rewardDelta = rewardRate * (lastTime - updatedAt) * 1e18 / totalSupply;
            rewardPerTokenStored += rewardDelta;
        }

        updatedAt = lastTime;

        if (account != address(0)) {
            // Inline earned() to avoid second rewardPerToken() + function call
            rewards[account] = (balanceOf[account] * (rewardPerTokenStored - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    function stake(uint256 amount) external nonReentrant {
        _updateReward(msg.sender);                    // ← GAS WIN: single computation

        if (amount == 0) revert CannotStakeZero();

        // Unchecked: safe because amount > 0 and we never overflow reasonable token supplies
        unchecked {
            totalSupply += amount;
            balanceOf[msg.sender] += amount;
        }

        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        _updateReward(msg.sender);                    // ← GAS WIN: single computation

        if (amount == 0) revert CannotWithdrawZero();
        if (balanceOf[msg.sender] < amount) revert InsufficientStakedBalance();

        // Unchecked: safe because of the balance check above
        unchecked {
            totalSupply -= amount;
            balanceOf[msg.sender] -= amount;
        }

        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external nonReentrant {
        _updateReward(msg.sender);                    // ← GAS WIN: single computation

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // Owner sets new duration (only after current period ends)
    function setRewardsDuration(uint256 _duration) external onlyOwner {
        if (block.timestamp < finishAt) revert PreviousRewardsPeriodMustFinish();
        duration = _duration;
        emit RewardsDurationUpdated(_duration);
    }

    // Owner notifies new rewards (transfers must be done prior if needed)
    function notifyRewardAmount(uint256 reward) external onlyOwner {
        _updateReward(address(0));                    // ← GAS WIN: single computation

        if (block.timestamp >= finishAt) {
            rewardRate = reward / duration;
        } else {
            uint256 remaining = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (reward + remaining) / duration;
        }

        if (rewardRate == 0) revert RewardRateMustBePositive();

        updatedAt = block.timestamp;
        finishAt = block.timestamp + duration;
        emit RewardAdded(reward);
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a <= b ? a : b;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
