// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PorkelonPresale
 * @dev Manages PORK token presale with MATIC and USDT payments.
 */
contract PorkelonPresale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public immutable token;
    IERC20 public immutable usdt;
    uint256 public immutable tokenPriceMatic;
    uint256 public immutable tokenPriceUsdt;
    uint256 public immutable minPurchase;
    uint256 public immutable maxPurchase;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable cap;
    uint256 public sold;
    address public fundsWallet;

    event Bought(address indexed buyer, uint256 amountPaid, uint256 tokenAmount, bool isMatic);
    event FundsWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event TokensWithdrawn(address indexed owner, uint256 amount);

    constructor(
        IERC20 _token,
        IERC20 _usdt,
        uint256 _tokenPriceMatic,
        uint256 _tokenPriceUsdt,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _cap
    ) Ownable(msg.sender) {
        require(address(_token) != address(0), "PorkelonPresale: Invalid token address");
        require(address(_usdt) != address(0), "PorkelonPresale: Invalid USDT address");
        require(_tokenPriceMatic > 0, "PorkelonPresale: Invalid MATIC price");
        require(_tokenPriceUsdt > 0, "PorkelonPresale: Invalid USDT price");
        require(_minPurchase > 0, "PorkelonPresale: Invalid min purchase");
        require(_maxPurchase >= _minPurchase, "PorkelonPresale: Max < min purchase");
        require(_startTime > block.timestamp, "PorkelonPresale: Start time in past");
        require(_endTime > _startTime, "PorkelonPresale: End time <= start");
        require(_cap > 0, "PorkelonPresale: Invalid cap");

        token = _token;
        usdt = _usdt;
        tokenPriceMatic = _tokenPriceMatic;
        tokenPriceUsdt = _tokenPriceUsdt;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        startTime = _startTime;
        endTime = _endTime;
        cap = _cap;
        fundsWallet = msg.sender;
    }

    function buyWithMatic() external payable nonReentrant {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "PorkelonPresale: Not active");
        require(msg.value >= minPurchase && msg.value <= maxPurchase, "PorkelonPresale: Invalid MATIC amount");
        uint256 tokenAmount = msg.value.mul(tokenPriceMatic);
        require(sold.add(tokenAmount) <= cap, "PorkelonPresale: Cap exceeded");

        sold = sold.add(tokenAmount);
        require(token.transfer(msg.sender, tokenAmount), "PorkelonPresale: Token transfer failed");
        payable(fundsWallet).transfer(msg.value);
        emit Bought(msg.sender, msg.value, tokenAmount, true);
    }

    function buyWithUsdt(uint256 usdtAmount) external nonReentrant {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "PorkelonPresale: Not active");
        require(usdtAmount >= minPurchase && usdtAmount <= maxPurchase, "PorkelonPresale: Invalid USDT amount");
        uint256 tokenAmount = usdtAmount.mul(tokenPriceUsdt);
        require(sold.add(tokenAmount) <= cap, "PorkelonPresale: Cap exceeded");

        sold = sold.add(tokenAmount);
        require(usdt.transferFrom(msg.sender, fundsWallet, usdtAmount), "PorkelonPresale: USDT transfer failed");
        require(token.transfer(msg.sender, tokenAmount), "PorkelonPresale: Token transfer failed");
        emit Bought(msg.sender, usdtAmount, tokenAmount, false);
    }

    function setFundsWallet(address _newWallet) external onlyOwner {
        require(_newWallet != address(0), "PorkelonPresale: Invalid wallet");
        address oldWallet = fundsWallet;
        fundsWallet = _newWallet;
        emit FundsWalletUpdated(oldWallet, _newWallet);
    }

    function withdrawRemainingTokens() external onlyOwner {
        require(block.timestamp > endTime, "PorkelonPresale: Still active");
        uint256 remaining = token.balanceOf(address(this));
        require(remaining > 0, "PorkelonPresale: No tokens to withdraw");
        require(token.transfer(owner(), remaining), "PorkelonPresale: Token transfer failed");
        emit TokensWithdrawn(owner(), remaining);
    }
}
