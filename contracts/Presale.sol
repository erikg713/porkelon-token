// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PORKELON Presale (Polygon Mainnet)
/// @notice Fixed-parameter presale contract for Polygon (MATIC + USDT).
/// @dev Solidity 0.8.24 (Paris) — immutable tokenomics.

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ------------------------------------------------------------
    // Constants & Fixed Tokenomics
    // ------------------------------------------------------------

    IERC20 public immutable token;        // PORKELON token (18 decimals)
    IERC20 public immutable usdt;         // USDT (6 decimals)
    address payable public immutable fundsWallet;

    uint256 public constant MATIC_RATE = 100000; // 1 MATIC = 100k PORK
    uint256 public constant USDT_RATE  = 100000; // 1 USDT = 100k PORK
    uint256 public constant CAP        = 500_000_000 * 1e18; // 500M PORK
    uint256 public constant MIN_PURCHASE = 0.1 ether; // 0.1 MATIC
    uint256 public constant MAX_PURCHASE = 5 ether;   // 5 MATIC
    uint256 public constant PER_WALLET_CAP = 10_000_000 * 1e18; // 10M PORK per wallet

    uint256 public constant GOAL_USD = 25_000_000 * 10**6; // $25M USDT equivalent
    uint256 public constant MATIC_USD_PRICE = 50 * 10**6;  // Example: 1 MATIC = $50 USDT (adjust if needed)

    uint256 private constant USDT_DECIMALS = 10**6;
    uint256 private constant MATIC_DECIMALS = 1 ether;

    // ------------------------------------------------------------
    // State
    // ------------------------------------------------------------

    uint256 public tokensSold;
    uint256 public usdRaised;
    bool public presaleActive;

    mapping(address => uint256) public purchased;

    uint256 public immutable startTime;
    uint256 public immutable endTime;

    // ------------------------------------------------------------
    // Events
    // ------------------------------------------------------------

    event PresaleStarted(uint256 start, uint256 end);
    event PresaleEnded(uint256 end, uint256 usdRaised);
    event BoughtWithMatic(address indexed buyer, uint256 matic, uint256 tokens, uint256 usd);
    event BoughtWithUSDT(address indexed buyer, uint256 usdt, uint256 tokens);

    // ------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------

    constructor(address _token, address _usdt, address payable _wallet) {
        require(_token != address(0) && _usdt != address(0) && _wallet != address(0), "Zero address");

        token = IERC20(_token);
        usdt = IERC20(_usdt);
        fundsWallet = _wallet;

        // Auto start at midnight UTC tonight
        uint256 today = block.timestamp - (block.timestamp % 1 days);
        uint256 nextMidnight = today + 1 days;
        startTime = nextMidnight;
        endTime = startTime + 30 days;
        presaleActive = true;

        emit PresaleStarted(startTime, endTime);
    }

    // ------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------

    modifier onlyWhileActive() {
        require(presaleActive, "Presale not active");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Not in presale window");
        require(usdRaised < GOAL_USD, "Goal reached");
        _;
    }

    // ------------------------------------------------------------
    // Public Functions
    // ------------------------------------------------------------

    /// @notice Buy tokens using MATIC
    function buyWithMatic() external payable nonReentrant onlyWhileActive {
        uint256 maticAmount = msg.value;
        require(maticAmount >= MIN_PURCHASE && maticAmount <= MAX_PURCHASE, "MATIC limits");

        uint256 tokenAmount = (maticAmount * MATIC_RATE) / MATIC_DECIMALS;
        require(tokenAmount > 0, "Zero token");

        uint256 newSold = tokensSold + tokenAmount;
        require(newSold <= CAP, "Cap exceeded");

        uint256 newPurchased = purchased[msg.sender] + tokenAmount;
        require(newPurchased <= PER_WALLET_CAP, "Wallet cap exceeded");

        tokensSold = newSold;
        purchased[msg.sender] = newPurchased;

        uint256 usdAmount = (maticAmount * MATIC_USD_PRICE) / MATIC_DECIMALS;
        usdRaised += usdAmount;

        token.safeTransfer(msg.sender, tokenAmount);
        (bool sent, ) = fundsWallet.call{value: maticAmount}("");
        require(sent, "Transfer failed");

        if (usdRaised >= GOAL_USD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithMatic(msg.sender, maticAmount, tokenAmount, usdAmount);
    }

    /// @notice Buy tokens using USDT
    function buyWithUSDT(uint256 usdtAmount) external nonReentrant onlyWhileActive {
        require(usdtAmount > 0, "Zero USDT");

        uint256 tokenAmount = (usdtAmount * USDT_RATE) / USDT_DECIMALS;
        require(tokenAmount > 0, "Zero token");

        uint256 newSold = tokensSold + tokenAmount;
        require(newSold <= CAP, "Cap exceeded");

        uint256 newPurchased = purchased[msg.sender] + tokenAmount;
        require(newPurchased <= PER_WALLET_CAP, "Wallet cap exceeded");

        tokensSold = newSold;
        purchased[msg.sender] = newPurchased;

        usdRaised += usdtAmount;

        usdt.safeTransferFrom(msg.sender, fundsWallet, usdtAmount);
        token.safeTransfer(msg.sender, tokenAmount);

        if (usdRaised >= GOAL_USD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithUSDT(msg.sender, usdtAmount, tokenAmount);
    }

    // ------------------------------------------------------------
    // Owner / Admin Functions
    // ------------------------------------------------------------

    function endPresale() external onlyOwner {
        presaleActive = false;
        emit PresaleEnded(block.timestamp, usdRaised);
    }

    function withdrawERC20(address erc20, address to) external onlyOwner {
        require(to != address(0), "Zero to");
        IERC20 erc = IERC20(erc20);
        uint256 bal = erc.balanceOf(address(this));
        require(bal > 0, "No balance");
        erc.safeTransfer(to, bal);
    }

    function emergencyWithdrawMatic() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No MATIC");
        (bool sent, ) = owner().call{value: bal}("");
        require(sent, "Withdraw failed");
    }

    // ------------------------------------------------------------
    // Views
    // ------------------------------------------------------------

    function remainingTokens() external view returns (uint256) {
        return CAP > tokensSold ? CAP - tokensSold : 0;
    }

    function isLive() external view returns (bool) {
        return presaleActive && block.timestamp >= startTime && block.timestamp <= endTime && usdRaised < GOAL_USD;
    }

    // ------------------------------------------------------------
    // Fallback
    // ------------------------------------------------------------

    receive() external payable {}
    fallback() external payable {}
}
