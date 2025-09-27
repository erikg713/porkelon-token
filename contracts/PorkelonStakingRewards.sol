// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PorkelonStakingRewards is Ownable {
    IERC20 public stakingToken;
    IERC20 public rewardsToken;
    uint256 public rewardPool;
    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public stakingStartTime;

    constructor(address _stakingToken, address _rewardsToken, uint256 _rewardPool) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        rewardPool = _rewardPool;
    }

    // Stake tokens
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakingToken.balanceOf(msg.sender) >= amount, "Insufficient balance");

        if (stakingBalance[msg.sender] > 0) {
            _claimRewards(msg.sender);
        } else {
            stakingStartTime[msg.sender] = block.timestamp;
        }

        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakingBalance[msg.sender] += amount;
    }

    // Unstake tokens with rewards
    function unstake() external {
        uint256 staked = stakingBalance[msg.sender];
        require(staked > 0, "No tokens staked");

        uint256 reward = _calculateRewards(msg.sender);
        stakingBalance[msg.sender] = 0;
        stakingStartTime[msg.sender] = 0;

        stakingToken.transfer(msg.sender, staked);
        if (reward > 0 && reward <= rewardPool) {
            rewardsToken.transfer(msg.sender, reward);
            rewardPool -= reward;
        }
    }

    // Calculate rewards (0.1% per day)
    function _calculateRewards(address account) internal view returns (uint256) {
        uint256 staked = stakingBalance[account];
        if (staked == 0) return 0;

        uint256 duration = block.timestamp - stakingStartTime[account];
        return (staked * duration * 1) / (1000 * 1 days);
    }

    // Claim rewards without unstaking
    function claimRewards() external {
        uint256 reward = _calculateRewards(msg.sender);
        require(reward > 0, "No rewards available");
        require(reward <= rewardPool, "Insufficient reward pool");

        stakingStartTime[msg.sender] = block.timestamp;
        rewardsToken.transfer(msg.sender, reward);
        rewardPool -= reward;
    }
}
