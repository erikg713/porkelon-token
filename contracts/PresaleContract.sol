// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  PresaleContract.sol
  - Handles presale for an ERC20 token.
  - Buyers pay with native currency (e.g., MATIC).
  - Owner sets price, withdraws proceeds.
  - Tokens are transferred from contract's balance (owner must approve or deposit tokens first).
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PresaleContract is Ownable, ReentrancyGuard {
    IERC20 public token; // The ERC20 token being sold
    uint256 public presalePriceWeiPerToken; // Wei per full token (10^18 units)
    uint256 public presaleCap; // Max tokens available for presale
    uint256 public tokensSold;

    uint256 public constant DECIMAL_FACTOR = 10**18;

    event PresaleBuy(address indexed buyer, uint256 tokenAmount, uint256 paidWei);
    event PresalePriceSet(uint256 weiPerToken);
    event PresaleCapSet(uint256 cap);

    constructor(IERC20 _token, uint256 _initialCap) {
        token = _token;
        presaleCap = _initialCap;
        presalePriceWeiPerToken = 0; // Owner must set
    }

    // Owner sets presale price in wei per full token
    function setPresalePrice(uint256 weiPerToken) external onlyOwner {
        presalePriceWeiPerToken = weiPerToken;
        emit PresalePriceSet(weiPerToken);
    }

    // Owner sets or updates presale cap
    function setPresaleCap(uint256 newCap) external onlyOwner {
        presaleCap = newCap;
        emit PresaleCapSet(newCap);
    }

    // Buy presale tokens
    function buyPresale(uint256 tokenAmount) external payable nonReentrant {
        require(presalePriceWeiPerToken > 0, "presale price not set");
        require(tokenAmount > 0, "zero tokens");
        uint256 weiRequired = (presalePriceWeiPerToken * tokenAmount) / DECIMAL_FACTOR;
        require(msg.value >= weiRequired, "insufficient payment");
        require(tokensSold + tokenAmount <= presaleCap, "exceeds presale cap");

        tokensSold += tokenAmount;

        // Transfer tokens to buyer
        require(token.transfer(msg.sender, tokenAmount), "token transfer failed");

        // Refund overpayment
        if (msg.value > weiRequired) {
            (bool sent, ) = msg.sender.call{value: msg.value - weiRequired}("");
            require(sent, "refund failed");
        }

        emit PresaleBuy(msg.sender, tokenAmount, weiRequired);
    }

    // Owner withdraws accumulated native funds
    function withdrawProceeds(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "zero address");
        uint256 bal = address(this).balance;
        require(bal > 0, "no proceeds");
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "withdraw failed");
    }

    // Owner can deposit more tokens if needed (or approve this contract to spend from token contract/minter)
    function depositTokens(uint256 amount) external onlyOwner {
        require(token.transferFrom(msg.sender, address(this), amount), "deposit failed");
    }

    receive() external payable {}
}
