// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PorkelonMarketingVault is Ownable {
    IERC20 public token;
    uint256 public marketingPool;

    event MarketingWithdrawn(address indexed to, uint256 amount);

    constructor(IERC20 _token, uint256 _marketingPool) Ownable(msg.sender) {
        token = _token;
        marketingPool = _marketingPool;
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        require(amount <= marketingPool, "Not enough funds");
        marketingPool -= amount;
        require(token.transfer(to, amount), "Transfer failed");
        emit MarketingWithdrawn(to, amount);
    }
}
