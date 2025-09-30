// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // IMPORT for safer transfers

/**
 * @title PorkelonLiquidityLocker
 * @dev Locks tokens for liquidity with a 1-year release schedule.
 */
contract PorkelonLiquidityLocker is Ownable {
    using SafeERC20 for IERC20; // USE the SafeERC20 library

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable lockAmount;
    uint256 public immutable releaseTime;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(
        address _tokenAddress, // UPDATED: Use address type for constructor argument
        address _beneficiary,
        uint256 _lockAmount
    ) Ownable(msg.sender) { // CORRECT for OZ v5
        require(_tokenAddress != address(0), "PorkelonLocker: Invalid token address");
        require(_beneficiary != address(0), "PorkelonLocker: Invalid beneficiary");
        require(_lockAmount > 0, "PorkelonLocker: Invalid lock amount");

        token = IERC20(_tokenAddress);
        beneficiary = _beneficiary;
        lockAmount = _lockAmount;
        releaseTime = block.timestamp + 365 days;
    }

    /**
     * @notice Releases the locked tokens to the beneficiary after the lock period.
     * @dev Anyone can call this function to trigger the release for the beneficiary.
     */
    function release() external { // IMPROVEMENT: Removed onlyOwner for trustless release
        require(block.timestamp >= releaseTime, "PorkelonLocker: Tokens still locked");
        
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "PorkelonLocker: No tokens to release");
        
        token.safeTransfer(beneficiary, amount); // UPDATED: Use safeTransfer
        
        emit TokensReleased(beneficiary, amount);
    }
}
