// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PorkelonStakingRewards is Ownable, ReentrancyGuard {
    IERC20 public stakingToken;
    IERC20 public rewardsToken;

    uint256 public totalStaked;
    mapping(address => uint256) public balancesStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public rewardsPool;

    event Stake(address indexed user, uint256 amount);
    event WithdrawStake(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardNotified(uint256 amount, uint256 duration);

    constructor(IERC20 _stakingToken, IERC20 _rewardsToken, uint256 _initialRewardsPool) Ownable(msg.sender) {
        stakingToken = _stakingToken;
        rewardsToken = _rewardsToken;
        rewardsPool = _initialRewardsPool;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (balancesStaked[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    function notifyRewardAmount(uint256 rewardAmount, uint256 durationSeconds) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "Previous period not finished");
        require(rewardAmount <= rewardsPool, "Not enough rewards");
        require(durationSeconds > 0, "Duration zero");

        rewardsPool -= rewardAmount;
        rewardRate = rewardAmount / durationSeconds;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + durationSeconds;

        emit RewardNotified(rewardAmount, durationSeconds);
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Zero stake");
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        balancesStaked[msg.sender] += amount;
        totalStaked += amount;
        emit Stake(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Zero withdraw");
        require(balancesStaked[msg.sender] >= amount, "Insufficient staked");
        balancesStaked[msg.sender] -= amount;
        totalStaked -= amount;
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");
        emit WithdrawStake(msg.sender, amount);
    }

    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardsToken.transfer(msg.sender, reward), "Transfer failed");
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balancesStaked[msg.sender]);
        getReward();
    }

    function topUpRewards(uint256 amount) external onlyOwner {
        require(rewardsToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        rewardsPool += amount;
    }
}
