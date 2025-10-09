// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Porkelon Presale (Polygon)
/// @notice Fixed tokenomics presale: MATIC + USDT purchases. Starts at next midnight UTC, runs 30 days.
/// @dev Solidity 0.8.24 — use Hardhat optimizer runs = 200, evmVersion = "paris".

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // -----------------------------
    // Token / funds
    // -----------------------------
    IERC20 public immutable token; // PORK (18 decimals)
    IERC20 public immutable usdt;  // USDT (6 decimals)

    // Funds receiver (dev wallet) — corrected address
    address payable public constant FUNDS_WALLET = payable(0xcfe1f215d199b24f240711b3a7Cf30453D8F4566);

    // -----------------------------
    // Fixed tokenomics (immutable)
    // -----------------------------
    uint256 public constant MATIC_RATE = 100_000;               // 1 MATIC = 100k PORK
    uint256 public constant USDT_RATE  = 100_000;               // 1 USDT  = 100k PORK
    uint256 public constant CAP        = 500_000_000 * 1e18;    // 500M PORK
    uint256 public constant MIN_PURCHASE = 0.1 ether;           // 0.1 MATIC
    uint256 public constant MAX_PURCHASE = 5 ether;             // 5 MATIC
    uint256 public constant PER_WALLET_CAP = 10_000_000 * 1e18; // 10M PORK per wallet

    uint256 public constant GOAL_USD = 25_000_000 * 10**6;      // 25M USDT
    uint256 public constant MATIC_USD_PRICE = 50 * 10**6;       // 1 MATIC = $50 (6 decimals)

    uint256 private constant USDT_DECIMALS = 10**6;
    uint256 private constant MATIC_DECIMALS = 1 ether;

    // -----------------------------
    // State
    // -----------------------------
    uint256 public tokensSold;
    uint256 public usdRaised;
    bool public presaleActive;

    mapping(address => uint256) public purchased;

    uint256 public immutable startTime;
    uint256 public immutable endTime;

    // -----------------------------
    // Events
    // -----------------------------
    event PresaleStarted(uint256 startTime, uint256 endTime);
    event PresaleEnded(uint256 timestamp, uint256 usdRaised);
    event BoughtWithMatic(address indexed buyer, uint256 maticAmount, uint256 tokenAmount, uint256 usdAmount);
    event BoughtWithUSDT(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount);
    event ERC20Withdraw(address indexed token, address indexed to, uint256 amount);
    event EmergencyWithdraw(address indexed to, uint256 amount);

    // -----------------------------
    // Constructor
    // -----------------------------
    constructor(address _token, address _usdt) {
        require(_token != address(0), "token zero");
        require(_usdt != address(0), "usdt zero");

        token = IERC20(_token);
        usdt = IERC20(_usdt);

        uint256 dayStart = block.timestamp - (block.timestamp % 1 days);
        uint256 nextMidnight = dayStart + 1 days;
        startTime = nextMidnight;
        endTime = startTime + 30 days;

        presaleActive = true;
        emit PresaleStarted(startTime, endTime);
    }

    // -----------------------------
    // Modifiers
    // -----------------------------
    modifier onlyWhileActive() {
        require(presaleActive, "presale not active");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "outside window");
        require(usdRaised < GOAL_USD, "goal reached");
        _;
    }

    // -----------------------------
    // Purchase: MATIC
    // -----------------------------
    function buyWithMatic() external payable nonReentrant onlyWhileActive {
        uint256 maticAmount = msg.value;
        require(maticAmount >= MIN_PURCHASE && maticAmount <= MAX_PURCHASE, "matic limits");

        uint256 tokenAmount = (maticAmount * MATIC_RATE) / MATIC_DECIMALS;
        require(tokenAmount > 0, "zero tokens");

        uint256 newSold = tokensSold + tokenAmount;
        require(newSold <= CAP, "cap exceeded");

        uint256 newPurchased = purchased[msg.sender] + tokenAmount;
        require(newPurchased <= PER_WALLET_CAP, "wallet cap exceeded");

        tokensSold = newSold;
        purchased[msg.sender] = newPurchased;

        uint256 usdAmount = (maticAmount * MATIC_USD_PRICE) / MATIC_DECIMALS;
        usdRaised += usdAmount;

        token.safeTransfer(msg.sender, tokenAmount);

        (bool sent, ) = FUNDS_WALLET.call{value: maticAmount}("");
        require(sent, "funds transfer failed");

        if (usdRaised >= GOAL_USD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithMatic(msg.sender, maticAmount, tokenAmount, usdAmount);
    }

    // -----------------------------
    // Purchase: USDT
    // -----------------------------
    function buyWithUSDT(uint256 usdtAmount) external nonReentrant onlyWhileActive {
        require(usdtAmount > 0, "zero usdt");

        uint256 tokenAmount = (usdtAmount * USDT_RATE) / USDT_DECIMALS;
        require(tokenAmount > 0, "zero tokens");

        uint256 newSold = tokensSold + tokenAmount;
        require(newSold <= CAP, "cap exceeded");

        uint256 newPurchased = purchased[msg.sender] + tokenAmount;
        require(newPurchased <= PER_WALLET_CAP, "wallet cap exceeded");

        tokensSold = newSold;
        purchased[msg.sender] = newPurchased;

        usdRaised += usdtAmount;

        usdt.safeTransferFrom(msg.sender, FUNDS_WALLET, usdtAmount);
        token.safeTransfer(msg.sender, tokenAmount);

        if (usdRaised >= GOAL_USD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithUSDT(msg.sender, usdtAmount, tokenAmount);
    }

    // -----------------------------
    // Owner / emergency
    // -----------------------------
    function endPresale() external onlyOwner {
        presaleActive = false;
        emit PresaleEnded(block.timestamp, usdRaised);
    }

    function withdrawERC20(address erc20, address to) external onlyOwner {
        require(to != address(0), "to zero");
        IERC20 erc = IERC20(erc20);
        uint256 bal = erc.balanceOf(address(this));
        require(bal > 0, "no balance");
        erc.safeTransfer(to, bal);
        emit ERC20Withdraw(erc20, to, bal);
    }

    function emergencyWithdrawMatic() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "no matic");
        (bool sent, ) = owner().call{value: bal}("");
        require(sent, "withdraw failed");
        emit EmergencyWithdraw(owner(), bal);
    }

    // -----------------------------
    // Views
    // -----------------------------
    function remainingTokens() external view returns (uint256) {
        return CAP > tokensSold ? CAP - tokensSold : 0;
    }

    function isLive() external view returns (bool) {
        return presaleActive && block.timestamp >= startTime && block.timestamp <= endTime && usdRaised < GOAL_USD;
    }

    // -----------------------------
    // Receive / Fallback
    // -----------------------------
    receive() external payable {}
    fallback() external payable {}
}
