// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;   // PORK token
    IERC20 public immutable usdt;    // USDT (or stable)
    address public fundsWallet;      // where raised funds go

    uint256 public maticRate;        // tokens per 1 MATIC
    uint256 public usdtRate;         // tokens per 1 USDT (6 decimals)
    uint256 public cap;              // total tokens allocated for presale
    uint256 public tokensSold;

    uint256 public startTime;
    uint256 public endTime;
    bool public presaleActive;

    uint256 public minPurchaseMatic;
    uint256 public maxPurchaseMatic;
    uint256 public perWalletCap;

    uint256 public goalUSD = 25_000_000 * 10**6; // 25M USDT base units
    uint256 public usdRaised; 
    uint256 public maticUsdPrice; // 1 MATIC price in USDT base units

    mapping(address => uint256) public purchased;

    event PresaleStarted(uint256 startTime, uint256 endTime);
    event PresaleEnded(uint256 timestamp, uint256 usdRaised);
    event BoughtWithMatic(address indexed buyer, uint256 maticAmount, uint256 tokenAmount);
    event BoughtWithUSDT(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event ERC20Withdraw(address indexed token, address indexed to, uint256 amount);

    constructor(
        address _token,
        address _usdt,
        address _fundsWallet,
        uint256 _maticRate,
        uint256 _usdtRate,
        uint256 _cap,
        uint256 _minPurchaseMatic,
        uint256 _maxPurchaseMatic,
        uint256 _perWalletCap,
        uint256 _localOffsetHours,     // e.g. -4 for EDT
        uint256 _maticUsdPrice         // price of 1 MATIC in USDT base units
    ) {
        require(_token != address(0), "token=0");
        require(_usdt != address(0), "usdt=0");
        require(_fundsWallet != address(0), "funds=0");
        require(_maticRate > 0 && _usdtRate > 0 && _maticUsdPrice > 0, "rate>0");
        require(_cap > 0, "cap>0");

        token = IERC20(_token);
        usdt = IERC20(_usdt);
        fundsWallet = _fundsWallet;

        maticRate = _maticRate;
        usdtRate = _usdtRate;
        cap = _cap;
        maticUsdPrice = _maticUsdPrice;

        minPurchaseMatic = _minPurchaseMatic;
        maxPurchaseMatic = _maxPurchaseMatic;
        perWalletCap = _perWalletCap;

        // Set start = today 3PM local, end = 30 days later
        uint256 today = block.timestamp - (block.timestamp % 1 days);
        startTime = today + (15 - _localOffsetHours) * 1 hours;
        endTime = startTime + 30 days;

        presaleActive = true;
        emit PresaleStarted(startTime, endTime);
    }

    modifier onlyWhileActive() {
        require(presaleActive && block.timestamp >= startTime && block.timestamp <= endTime, "presale not active");
        require(usdRaised < goalUSD, "goal reached");
        _;
    }

    function endPresale() public onlyOwner {
        presaleActive = false;
        emit PresaleEnded(block.timestamp, usdRaised);
    }

    function setFundsWallet(address _fundsWallet) external onlyOwner {
        require(_fundsWallet != address(0), "funds=0");
        fundsWallet = _fundsWallet;
    }

    function setRates(uint256 _maticRate, uint256 _usdtRate, uint256 _maticUsdPrice) external onlyOwner {
        require(_maticRate > 0 && _usdtRate > 0 && _maticUsdPrice > 0, "rates>0");
        maticRate = _maticRate;
        usdtRate = _usdtRate;
        maticUsdPrice = _maticUsdPrice;
    }

    function buyWithMatic() external payable nonReentrant onlyWhileActive {
        uint256 maticAmount = msg.value;
        require(maticAmount >= minPurchaseMatic, "below min");
        require(maticAmount <= maxPurchaseMatic, "above max");

        uint256 tokenAmount = (maticAmount * maticRate) / 1 ether;
        require(tokenAmount > 0, "token=0");
        require(tokensSold + tokenAmount <= cap, "cap exceeded");
        require(token.balanceOf(address(this)) >= tokenAmount, "not enough tokens");
        require(purchased[msg.sender] + tokenAmount <= perWalletCap, "wallet cap");

        tokensSold += tokenAmount;
        purchased[msg.sender] += tokenAmount;

        // track USD raised
        usdRaised += (maticAmount * maticUsdPrice) / 1 ether;

        token.safeTransfer(msg.sender, tokenAmount);

        (bool sent, ) = fundsWallet.call{value: maticAmount}("");
        require(sent, "matic transfer failed");

        if (usdRaised >= goalUSD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithMatic(msg.sender, maticAmount, tokenAmount);
    }

    function buyWithUSDT(uint256 usdtAmount) external nonReentrant onlyWhileActive {
        require(usdtAmount > 0, "usdt=0");

        uint256 tokenAmount = (usdtAmount * usdtRate) / (10**6);
        require(tokenAmount > 0, "token=0");
        require(tokensSold + tokenAmount <= cap, "cap exceeded");
        require(token.balanceOf(address(this)) >= tokenAmount, "not enough tokens");
        require(purchased[msg.sender] + tokenAmount <= perWalletCap, "wallet cap");

        tokensSold += tokenAmount;
        purchased[msg.sender] += tokenAmount;

        // track USD raised
        usdRaised += usdtAmount;

        usdt.safeTransferFrom(msg.sender, fundsWallet, usdtAmount);
        token.safeTransfer(msg.sender, tokenAmount);

        if (usdRaised >= goalUSD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithUSDT(msg.sender, usdtAmount, tokenAmount);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "no matic");
        (bool sent, ) = owner().call{value: bal}("");
        require(sent, "withdraw failed");
        emit EmergencyWithdraw(owner(), bal);
    }

    function withdrawERC20(address erc20, address to) external onlyOwner {
        require(to != address(0), "to=0");
        IERC20 erc = IERC20(erc20);
        uint256 bal = erc.balanceOf(address(this));
        require(bal > 0, "no token");
        SafeERC20.safeTransfer(erc, to, bal);
        emit ERC20Withdraw(erc20, to, bal);
    }

    function previewTokensForMatic(uint256 maticWei) external view returns (uint256) {
        return (maticWei * maticRate) / 1 ether;
    }

    function previewTokensForUSDT(uint256 usdtBase) external view returns (uint256) {
        return (usdtBase * usdtRate) / (10**6);
    }

    receive() external payable {}
    fallback() external payable {}
}
