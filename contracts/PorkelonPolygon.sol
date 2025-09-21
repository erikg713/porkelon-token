// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PorkelonPolygon is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18; // 100B tokens

    address public teamWallet;
    address public marketingWallet;
    address public liquidityWallet;

    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public stakingStartTime;

    constructor(
        address _teamWallet,
        address _marketingWallet,
        address _liquidityWallet
    ) ERC20("Porkelon", "PORK") {
        require(_teamWallet != address(0), "Invalid team wallet");
        require(_marketingWallet != address(0), "Invalid marketing wallet");
        require(_liquidityWallet != address(0), "Invalid liquidity wallet");

        teamWallet = _teamWallet;
        marketingWallet = _marketingWallet;
        liquidityWallet = _liquidityWallet;

        // Pre-allocate supply
        _mint(teamWallet, (MAX_SUPPLY * 20) / 100);       // 20B
        _mint(marketingWallet, (MAX_SUPPLY * 10) / 100);  // 10B
        _mint(liquidityWallet, (MAX_SUPPLY * 25) / 100);  // 25B
        // Remaining 45B reserved for migration & staking
        _mint(address(this), (MAX_SUPPLY * 45) / 100);
    }

    // --- Staking Mechanism ---
    function stake(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _transfer(msg.sender, address(this), amount);
        stakingBalance[msg.sender] += amount;
        stakingStartTime[msg.sender] = block.timestamp;
    }

    function unstake() external {
        uint256 staked = stakingBalance[msg.sender];
        require(staked > 0, "No tokens staked");

        // Example reward: 0.1% per day
        uint256 duration = block.timestamp - stakingStartTime[msg.sender];
        uint256 reward = (staked * duration * 1) / (1000 * 1 days);

        stakingBalance[msg.sender] = 0;
        stakingStartTime[msg.sender] = 0;
        _transfer(address(this), msg.sender, staked + reward);
    }
}
