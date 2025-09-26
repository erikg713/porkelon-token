// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PorkelonPresale
 * @dev Handles presale with MATIC payments for PORK tokens.
 */
contract PorkelonPresale is Ownable, ReentrancyGuard {
    IERC20 public token;
    uint256 public presalePriceWeiPerToken;
    uint256 public presalePool;
    uint256 public constant DECIMAL_FACTOR = 10**18;

    event PresaleBuy(address indexed buyer, uint256 tokenAmount, uint256 paidWei);

    constructor(IERC20 _token, uint256 _presalePool) Ownable(msg.sender) {
        token = _token;
        presalePool = _presalePool;
    }

    function setPresalePrice(uint256 weiPerToken) external onlyOwner {
        require(weiPerToken > 0, "Invalid price");
        presalePriceWeiPerToken = weiPerToken;
    }

    function buyPresale(uint256 tokenAmount) external payable nonReentrant {
        require(tokenAmount <= presalePool, "Not enough presale tokens");
        uint256 weiRequired = (presalePriceWeiPerToken * tokenAmount) / DECIMAL_FACTOR;
        require(msg.value >= weiRequired, "Insufficient payment");

        presalePool -= tokenAmount;
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");

        if (msg.value > weiRequired) {
            payable(msg.sender).transfer(msg.value - weiRequired);
        }

        emit PresaleBuy(msg.sender, tokenAmount, weiRequired);
    }

    function withdrawProceeds(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        uint256 bal = address(this).balance;
        to.transfer(bal);
    }
}
