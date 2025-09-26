// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PorkelonLiquidityLocker
 * @dev Locks PORK tokens for liquidity with a 1-year release schedule.
 */
contract PorkelonLiquidityLocker is Ownable {
    using SafeMath for uint256;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable lockAmount;
    uint256 public immutable releaseTime;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token, address _beneficiary, uint256 _lockAmount) Ownable(msg.sender) {
        require(address(_token) != address(0), "PorkelonLocker: Invalid token address");
        require(_beneficiary != address(0), "PorkelonLocker: Invalid beneficiary");
        require(_lockAmount > 0, "PorkelonLocker: Invalid lock amount");

        token = _token;
        beneficiary = _beneficiary;
        lockAmount = _lockAmount;
        releaseTime = block.timestamp + 365 days;
    }

    function release() external onlyOwner {
        require(block.timestamp >= releaseTime, "PorkelonLocker: Tokens still locked");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "PorkelonLocker: No tokens to release");
        require(token.transfer(beneficiary, amount), "PorkelonLocker: Transfer failed");
        emit TokensReleased(beneficiary, amount);
    }
}
