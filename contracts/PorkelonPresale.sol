// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PorkelonPresale is Ownable, ReentrancyGuard {
    IERC20 public porkelonToken; // The Porkelon ERC-20 token
    uint256 public tokenPrice; // Price in wei per token (e.g., 1e12 wei for 1 token = 0.000001 POL per token; adjust for your rate)
    uint256 public minPurchase; // Minimum POL to buy (in wei)
    uint256 public maxPurchase; // Maximum POL per buyer (in wei)
    uint256 public startTime; // Presale start timestamp
    uint256 public endTime; // Presale end timestamp
    uint256 public tokensSold; // Track tokens sold
    uint256 public presaleCap; // Total tokens available for presale (e.g., 30B)

    mapping(address => uint256) public contributions; // Track user contributions

    event TokensPurchased(address indexed buyer, uint256 amountPOL, uint256 tokensReceived);
    event PresaleFinalized(uint256 totalRaised);

    constructor(
        address _porkelonToken,
        uint256 _tokenPrice,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _presaleCap
    ) Ownable(msg.sender) {
        require(_porkelonToken != address(0), "Invalid token address");
        require(_tokenPrice > 0, "Invalid price");
        require(_minPurchase > 0 && _maxPurchase > _minPurchase, "Invalid purchase limits");
        require(_startTime >= block.timestamp && _endTime > _startTime, "Invalid times");
        require(_presaleCap > 0, "Invalid cap");

        porkelonToken = IERC20(_porkelonToken);
        tokenPrice = _tokenPrice;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        startTime = _startTime;
        endTime = _endTime;
        presaleCap = _presaleCap;
    }

    // Function for users to buy tokens
    function buyTokens() external payable nonReentrant {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        require(msg.value >= minPurchase && msg.value <= maxPurchase, "Invalid purchase amount");
        require(contributions[msg.sender] + msg.value <= maxPurchase, "Exceeds max per buyer");

        uint256 tokensToBuy = (msg.value * 1e18) / tokenPrice; // Assuming 18 decimals; adjust if different
        require(tokensSold + tokensToBuy <= presaleCap, "Exceeds presale cap");
        require(porkelonToken.balanceOf(address(this)) >= tokensToBuy, "Insufficient tokens in contract");

        contributions[msg.sender] += msg.value;
        tokensSold += tokensToBuy;

        porkelonToken.transfer(msg.sender, tokensToBuy);

        emit TokensPurchased(msg.sender, msg.value, tokensToBuy);
    }

    // Owner can finalize presale and withdraw funds (e.g., after endTime)
    function finalizePresale() external onlyOwner {
        require(block.timestamp > endTime, "Presale not ended");
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
        emit PresaleFinalized(balance);

        // Optionally, transfer any unsold tokens back to owner
        uint256 unsold = porkelonToken.balanceOf(address(this));
        if (unsold > 0) {
            porkelonToken.transfer(owner(), unsold);
        }
    }

    // Owner can update times if needed (before start)
    function updateTimes(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(block.timestamp < startTime, "Presale already started");
        require(_startTime >= block.timestamp && _endTime > _startTime, "Invalid times");
        startTime = _startTime;
        endTime = _endTime;
    }

    // Emergency withdraw in case of issues
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
        uint256 tokenBalance = porkelonToken.balanceOf(address(this));
        if (tokenBalance > 0) {
            porkelonToken.transfer(owner(), tokenBalance);
        }
    }

    // Receive function for direct POL sends (optional, but allows buyTokens via send)
    receive() external payable {
        buyTokens();
    }
}
