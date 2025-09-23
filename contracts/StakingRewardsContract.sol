// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  StakingRewardsContract.sol
  - Simple staking with time-bound rewards.
  - Users stake ERC20 tokens, earn rewards in the same or another token.
  - Owner notifies reward amounts and durations.
  - Includes pool for rewards (owner deposits rewards).
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingRewardsContract is Ownable, ReentrancyGuard {
    IERC20 public stakingToken; // Token to stake
    IERC20 public rewardsToken; // Token for rewards (can be same as stakingToken)

    uint256 public totalStaked;
    mapping(address => uint256) public balancesStaked;

    // Reward accounting
    uint256 public rewardRate; // Rewards per second
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards; // Earned but not claimed

    uint256 public constant DECIMAL_FACTOR = 10**18;

    event Stake(address indexed user, uint256 amount);
    event WithdrawStake(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardNotified(uint256 amount, uint256 duration);

    constructor(IERC20 _stakingToken, IERC20 _rewardsToken) {
        stakingToken = _stakingToken;
        rewardsToken = _rewardsToken;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;
    }

    // Owner notifies new reward distribution
    function notifyRewardAmount(uint256 rewardAmount, uint256 durationSeconds) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "previous period not finished");
        require(durationSeconds > 0, "duration zero");
        require(rewardAmount > 0, "reward zero");
        require(rewardsToken.balanceOf(address(this)) >= rewardAmount, "insufficient rewards balance");

        rewardRate = rewardAmount / durationSeconds;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + durationSeconds;

        emit RewardNotified(rewardAmount, durationSeconds);
    }

    // Stake tokens
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "zero stake");
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "stake transfer failed");
        balancesStaked[msg.sender] += amount;
        totalStaked += amount;
        emit Stake(msg.sender, amount);
    }

    // Withdraw stake
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "zero withdraw");
        require(balancesStaked[msg.sender] >= amount, "insufficient staked");
        balancesStaked[msg.sender] -= amount;
        totalStaked -= amount;
        require(stakingToken.transfer(msg.sender, amount), "withdraw transfer failed");
        emit WithdrawStake(msg.sender, amount);
    }

    // Claim rewards
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardsToken.transfer(msg.sender, reward), "reward transfer failed");
            emit RewardPaid(msg.sender, reward);
        }
    }

    // Exit: withdraw all stake and claim rewards
    function exit() external {
        withdraw(balancesStaked[msg.sender]);
        getReward();
    }

    // Last time reward applicable
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    // Reward per token
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 dt = lastTimeRewardApplicable() - lastUpdateTime;
        return rewardPerTokenStored + (dt * rewardRate * DECIMAL_FACTOR) / totalStaked;
    }

    // Earned rewards for account
    function earned(address account) public view returns (uint256) {
        return (balancesStaked[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / DECIMAL_FACTOR + rewards[account];
    }

    // Modifier to update reward
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // Owner deposits rewards tokens
    function depositRewards(uint256 amount) external onlyOwner {
        require(rewardsToken.transferFrom(msg.sender, address(this), amount), "deposit failed");
    }
}
