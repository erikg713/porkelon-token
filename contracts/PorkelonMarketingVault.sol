// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PorkelonMarketingVault
 * @dev Vests PORK tokens for marketing with linear release over 2 years.
 */
contract PorkelonMarketingVault is Ownable {
    using SafeMath for uint256;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable startTime;
    uint256 public immutable duration;
    uint256 public released;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token, address _beneficiary, uint256 _duration) Ownable(msg.sender) {
        require(address(_token) != address(0), "PorkelonVault: Invalid token address");
        require(_beneficiary != address(0), "PorkelonVault: Invalid beneficiary");
        require(_duration > 0, "PorkelonVault: Invalid duration");

        token = _token;
        beneficiary = _beneficiary;
        startTime = block.timestamp;
        duration = _duration;
    }

    function release() external onlyOwner {
        uint256 releasable = vestedAmount().sub(released);
        require(releasable > 0, "PorkelonVault: No tokens to release");
        released = released.add(releasable);
        require(token.transfer(beneficiary, releasable), "PorkelonVault: Transfer failed");
        emit TokensReleased(beneficiary, releasable);
    }

    function vestedAmount() public view returns (uint256) {
        uint256 totalBalance = token.balanceOf(address(this)).add(released);
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= startTime.add(duration)) {
            return totalBalance;
        } else {
            return totalBalance.mul(block.timestamp.sub(startTime)).div(duration);
        }
    }
}
