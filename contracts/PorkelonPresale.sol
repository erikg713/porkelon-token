// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PorkelonPresale
 * @dev Manages a presale for PORK tokens on Polygon with MATIC purchases.
 *      Only active during the specified time window with min/max purchase limits.
 */
contract PorkelonPresale is Ownable {
    using SafeMath for uint256;

    IERC20 public token; // PORK token (Porkelon.sol)
    uint256 public tokenPrice; // Tokens per MATIC (in wei)
    uint256 public minPurchase; // Minimum MATIC purchase (in wei)
    uint256 public maxPurchase; // Maximum MATIC purchase (in wei)
    uint256 public startTime; // Presale start timestamp
    uint256 public endTime; // Presale end timestamp
    uint256 public cap; // Total PORK tokens available for presale
    uint256 public sold; // Total PORK tokens sold
    address public fundsWallet; // Where MATIC funds are sent

    event Bought(address indexed buyer, uint256 maticAmount, uint256 tokenAmount);

    /**
     * @dev Constructor sets presale parameters.
     * @param _token Address of the PORK token contract.
     * @param _tokenPrice Tokens per MATIC (in wei).
     * @param _minPurchase Minimum MATIC purchase (in wei).
     * @param _maxPurchase Maximum MATIC purchase (in wei).
     * @param _startTime Presale start timestamp.
     * @param _endTime Presale end timestamp.
     * @param _cap Total PORK tokens available for presale.
     */
    constructor(
        IERC20 _token,
        uint256 _tokenPrice,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _cap
    ) Ownable(msg.sender) {
        require(address(_token) != address(0), "Invalid token address");
        require(_tokenPrice > 0, "Invalid token price");
        require(_minPurchase > 0, "Invalid min purchase");
        require(_maxPurchase >= _minPurchase, "Max purchase less than min");
        require(_startTime > block.timestamp, "Start time in past");
        require(_endTime > _startTime, "End time before start");
        require(_cap > 0, "Invalid cap");

        token = _token;
        tokenPrice = _tokenPrice;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        startTime = _startTime;
        endTime = _endTime;
        cap = _cap;
        fundsWallet = msg.sender; // Default to owner; can be updated
    }

    /**
     * @dev Allows users to buy PORK tokens with MATIC during the presale.
     */
    function buyWithMatic() external payable {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        require(msg.value >= minPurchase && msg.value <= maxPurchase, "Invalid MATIC amount");
        uint256 tokenAmount = msg.value.mul(tokenPrice);
        require(sold.add(tokenAmount) <= cap, "Presale cap exceeded");

        sold = sold.add(tokenAmount);
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
        payable(fundsWallet).transfer(msg.value);
        emit Bought(msg.sender, msg.value, tokenAmount);
    }

    /**
     * @dev Updates the funds wallet. Only callable by owner.
     * @param _newWallet New funds wallet address.
     */
    function setFundsWallet(address _newWallet) external onlyOwner {
        require(_newWallet != address(0), "Invalid wallet address");
        fundsWallet = _newWallet;
    }

    /**
     * @dev Withdraws remaining tokens after presale ends. Only callable by owner.
     */
    function withdrawRemainingTokens() external onlyOwner {
        require(block.timestamp > endTime, "Presale still active");
        uint256 remaining = token.balanceOf(address(this));
        require(remaining > 0, "No tokens to withdraw");
        require(token.transfer(owner(), remaining), "Token transfer failed");
    }
}
