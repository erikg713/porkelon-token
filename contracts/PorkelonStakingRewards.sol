// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PorkelonStakingRewards
 * @dev Staking contract for PORK tokens with time-based rewards.
 */
contract PorkelonStakingRewards is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    uint256 public rewardPool;
    uint256 public rewardRate;
    uint256 public constant REWARD_DURATION = 365 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardPoolUpdated(uint256 oldPool, uint256 newPool);

    constructor(IERC20 _stakingToken, IERC20 _rewardToken, uint256 _rewardPool) Ownable(msg.sender) {
        require(address(_stakingToken) != address(0), "PorkelonStaking: Invalid staking token");
        require(address(_rewardToken) != address(0), "PorkelonStaking: Invalid reward token");
        require(_rewardPool > 0, "PorkelonStaking: Invalid reward pool");
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardPool = _rewardPool;
        rewardRate = _rewardPool.div(REWARD_DURATION);
        lastUpdateTime = block.timestamp;
        emit RewardPoolUpdated(0, _rewardPool);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(
            block.timestamp.sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(totalStaked)
        );
    }

    function earned(address account) public view returns (uint256) {
        return balances[account].mul(
            rewardPerToken().sub(userRewardPerTokenPaid[account])
        ).div(1e18).add(rewards[account]);
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "PorkelonStaking: Invalid amount");
        totalStaked = totalStaked.add(amount);
        balances[msg.sender] = balances[msg.sender].add(amount);
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "PorkelonStaking: Transfer failed");
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "PorkelonStaking: Invalid amount");
        require(balances[msg.sender] >= amount, "PorkelonStaking: Insufficient balance");
        totalStaked = totalStaked.sub(amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        require(stakingToken.transfer(msg.sender, amount), "PorkelonStaking: Transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(reward <= rewardPool, "PorkelonStaking: Insufficient reward pool");
            rewardPool = rewardPool.sub(reward);
            require(rewardToken.transfer(msg.sender, reward), "PorkelonStaking: Reward transfer failed");
            emit RewardPaid(msg.sender, reward);
            emit RewardPoolUpdated(reward, rewardPool);
        }
    }
}
