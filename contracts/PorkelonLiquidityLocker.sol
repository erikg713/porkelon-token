// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PorkelonLiquidityLocker
 * @dev Locks PORK tokens for 1 year (intended for liquidity allocation).
 */
contract PorkelonLiquidityLocker is Ownable {
    IERC20 public token;
    address public beneficiary;
    uint256 public releaseTimestamp;
    uint256 public lockedAmount;
    bool public claimed;

    event LockedReleased(address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token, address _beneficiary, uint256 _lockedAmount) Ownable(msg.sender) {
        token = _token;
        beneficiary = _beneficiary;
        releaseTimestamp = block.timestamp + 365 days;
        lockedAmount = _lockedAmount;
    }

    function claim() external {
        require(msg.sender == beneficiary || msg.sender == owner(), "Not authorized");
        require(block.timestamp >= releaseTimestamp, "Still locked");
        require(!claimed, "Already claimed");
        claimed = true;
        require(token.transfer(beneficiary, lockedAmount), "Transfer failed");
        emit LockedReleased(beneficiary, lockedAmount);
    }
}
