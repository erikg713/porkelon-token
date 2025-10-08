// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PORK Token Presale
/// @author erikg713 (maintainer)
/// @notice Simple, gas-conscious presale contract supporting MATIC and USDT purchases.
/// - Owner can schedule or launch the presale immediately.
/// - Funds are forwarded to a configurable funds wallet.
/// - Per-wallet and per-tx limits are optional (0 = disabled).
contract Presale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* -------------------------------------------------------------------
       Errors (cheaper than strings)
       ------------------------------------------------------------------- */
    error ZeroAddress();
    error ZeroValue();
    error RateZero();
    error CapZero();
    error PresaleNotActive();
    error GoalReached();
    error BelowMin();
    error AboveMax();
    error TokenZero();
    error CapExceeded();
    error WalletCapExceeded();
    error MaticTransferFailed();
    error NoMatic();
    error NoTokenBalance();
    error ToZero();
    error AlreadyActive();
    error InvalidDuration();

    /* -------------------------------------------------------------------
       Immutables & config
       ------------------------------------------------------------------- */
    IERC20 public immutable token;        // PORK token (18 decimals assumed)
    IERC20 public immutable usdt;         // USDT (6 decimals)
    address payable public fundsWallet;   // where raised native/usdt funds go

    uint256 public maticRate;             // tokens per 1 MATIC (MATIC_DECIMALS)
    uint256 public usdtRate;              // tokens per 1 USDT (USDT_DECIMALS)
    uint256 public cap;                   // total tokens allocated for presale (token base units)

    /* -------------------------------------------------------------------
       State
       ------------------------------------------------------------------- */
    uint256 public tokensSold;
    uint256 public startTime;
    uint256 public endTime;
    bool public presaleActive;            // when true, buys allowed if inside [startTime, endTime]

    uint256 public minPurchaseMatic;      // wei, 0 = disabled
    uint256 public maxPurchaseMatic;      // wei, 0 = disabled
    uint256 public perWalletCap;          // token base units, 0 = disabled

    uint256 public goalUSD = 25_000_000 * 10**6; // USDT base units (6 decimals)
    uint256 public usdRaised;
    uint256 public maticUsdPrice;         // price of 1 MATIC in USDT base units (6 decimals)

    mapping(address => uint256) public purchased;

    /* -------------------------------------------------------------------
       Events
       ------------------------------------------------------------------- */
    event PresaleScheduled(uint256 startTime, uint256 endTime);
    event PresaleStarted(uint256 startTime, uint256 endTime);
    event PresaleEnded(uint256 timestamp, uint256 usdRaised);
    event BoughtWithMatic(address indexed buyer, uint256 maticAmount, uint256 tokenAmount, uint256 usdAmount);
    event BoughtWithUSDT(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event ERC20Withdraw(address indexed token, address indexed to, uint256 amount);
    event FundsWalletChanged(address indexed previous, address indexed current);
    event RatesUpdated(uint256 maticRate, uint256 usdtRate, uint256 maticUsdPrice);

    uint256 private constant USDT_DECIMALS = 10**6;
    uint256 private constant MATIC_DECIMALS = 1 ether;

    /* -------------------------------------------------------------------
       Constructor
       ------------------------------------------------------------------- */
    /// @param _localOffsetHours local timezone offset used to compute a sensible default start (can be negative)
    constructor(
        address _token,
        address _usdt,
        address payable _fundsWallet,
        uint256 _maticRate,
        uint256 _usdtRate,
        uint256 _cap,
        uint256 _minPurchaseMatic,
        uint256 _maxPurchaseMatic,
        uint256 _perWalletCap,
        int256  _localOffsetHours,
        uint256 _maticUsdPrice
    ) {
        if (_token == address(0) || _usdt == address(0) || _fundsWallet == address(0)) revert ZeroAddress();
        if (_maticRate == 0 || _usdtRate == 0 || _maticUsdPrice == 0) revert RateZero();
        if (_cap == 0) revert CapZero();

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

        // Compute a reasonable default start time (today at 15:00 local), but do NOT auto-start.
        uint256 dayStart = block.timestamp - (block.timestamp % 1 days);
        int256 targetHour = 15 - _localOffsetHours;
        int256 hourMod = ((targetHour % 24) + 24) % 24;
        startTime = dayStart + uint256(hourMod) * 1 hours;
        if (startTime < block.timestamp) startTime += 1 days;
        endTime = startTime + 30 days;

        // keep presale inactive until owner explicitly starts or schedules it
        presaleActive = false;
        emit PresaleScheduled(startTime, endTime);
    }

    /* -------------------------------------------------------------------
       Modifiers
       ------------------------------------------------------------------- */
    modifier onlyWhileActive() {
        if (!presaleActive || block.timestamp < startTime || block.timestamp > endTime) revert PresaleNotActive();
        if (usdRaised >= goalUSD) revert GoalReached();
        _;
    }

    /* -------------------------------------------------------------------
       Owner functions
       ------------------------------------------------------------------- */
    /// @notice Immediately launch the presale for `_durationDays` days (owner only).
    function launchPresaleNow(uint256 _durationDays) external onlyOwner {
        if (presaleActive) revert AlreadyActive();
        if (_durationDays == 0) revert InvalidDuration();
        startTime = block.timestamp;
        endTime = startTime + (_durationDays * 1 days);
        presaleActive = true;
        emit PresaleStarted(startTime, endTime);
    }

    /// @notice Schedule the presale at a given `_startTimestamp` for `_durationDays` days (owner only).
    function schedulePresaleAt(uint256 _startTimestamp, uint256 _durationDays) external onlyOwner {
        if (presaleActive) revert AlreadyActive();
        if (_startTimestamp <= block.timestamp) revert ZeroValue();
        if (_durationDays == 0) revert InvalidDuration();
        startTime = _startTimestamp;
        endTime = startTime + (_durationDays * 1 days);
        presaleActive = true;
        emit PresaleStarted(startTime, endTime);
    }

    function endPresale() external onlyOwner {
        if (!presaleActive) {
            // already ended — still emit for external visibility
            emit PresaleEnded(block.timestamp, usdRaised);
            return;
        }
        presaleActive = false;
        emit PresaleEnded(block.timestamp, usdRaised);
    }

    function setFundsWallet(address payable _fundsWallet) external onlyOwner {
        if (_fundsWallet == address(0)) revert ZeroAddress();
        address previous = fundsWallet;
        fundsWallet = _fundsWallet;
        emit FundsWalletChanged(previous, _fundsWallet);
    }

    function setRates(uint256 _maticRate, uint256 _usdtRate, uint256 _maticUsdPrice) external onlyOwner {
        if (_maticRate == 0 || _usdtRate == 0 || _maticUsdPrice == 0) revert RateZero();
        maticRate = _maticRate;
        usdtRate = _usdtRate;
        maticUsdPrice = _maticUsdPrice;
        emit RatesUpdated(_maticRate, _usdtRate, _maticUsdPrice);
    }

    /* -------------------------------------------------------------------
       Purchase functions
       ------------------------------------------------------------------- */
    /// @notice Buy using native MATIC. Token amount is floor(msg.value * maticRate / 1 ether).
    function buyWithMatic() external payable nonReentrant onlyWhileActive {
        uint256 maticAmount = msg.value;
        if (maticAmount == 0) revert ZeroValue();
        if (minPurchaseMatic != 0 && maticAmount < minPurchaseMatic) revert BelowMin();
        if (maxPurchaseMatic != 0 && maticAmount > maxPurchaseMatic) revert AboveMax();

        uint256 tokenAmount = (maticAmount * maticRate) / MATIC_DECIMALS;
        if (tokenAmount == 0) revert TokenZero();

        uint256 newTokensSold = tokensSold + tokenAmount;
        if (newTokensSold > cap) revert CapExceeded();

        uint256 newPurchased = purchased[msg.sender] + tokenAmount;
        if (perWalletCap != 0 && newPurchased > perWalletCap) revert WalletCapExceeded();

        unchecked {
            tokensSold = newTokensSold;
            purchased[msg.sender] = newPurchased;
        }

        // USD amount using maticUsdPrice in USDT base units
        uint256 usdAmount = (maticAmount * maticUsdPrice) / MATIC_DECIMALS;
        usdRaised += usdAmount;

        // transfer tokens first, then forward funds
        token.safeTransfer(msg.sender, tokenAmount);

        (bool sent, ) = fundsWallet.call{value: maticAmount}("");
        if (!sent) revert MaticTransferFailed();

        if (usdRaised >= goalUSD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithMatic(msg.sender, maticAmount, tokenAmount, usdAmount);
    }

    /// @notice Buy using USDT (expects 6 decimals). Transfers USDT to fundsWallet immediately.
    function buyWithUSDT(uint256 usdtAmount) external nonReentrant onlyWhileActive {
        if (usdtAmount == 0) revert ZeroValue();

        uint256 tokenAmount = (usdtAmount * usdtRate) / USDT_DECIMALS;
        if (tokenAmount == 0) revert TokenZero();

        uint256 newTokensSold = tokensSold + tokenAmount;
        if (newTokensSold > cap) revert CapExceeded();

        uint256 newPurchased = purchased[msg.sender] + tokenAmount;
        if (perWalletCap != 0 && newPurchased > perWalletCap) revert WalletCapExceeded();

        unchecked {
            tokensSold = newTokensSold;
            purchased[msg.sender] = newPurchased;
        }

        usdRaised += usdtAmount;

        usdt.safeTransferFrom(msg.sender, fundsWallet, usdtAmount);
        token.safeTransfer(msg.sender, tokenAmount);

        if (usdRaised >= goalUSD) {
            presaleActive = false;
            emit PresaleEnded(block.timestamp, usdRaised);
        }

        emit BoughtWithUSDT(msg.sender, usdtAmount, tokenAmount);
    }

    /* -------------------------------------------------------------------
       Admin / emergency
       ------------------------------------------------------------------- */
    function emergencyWithdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        if (bal == 0) revert NoMatic();
        (bool sent, ) = payable(owner()).call{value: bal}("");
        if (!sent) revert MaticTransferFailed();
        emit EmergencyWithdraw(owner(), bal);
    }

    function withdrawERC20(address erc20, address to) external onlyOwner {
        if (to == address(0)) revert ToZero();
        IERC20 erc = IERC20(erc20);
        uint256 bal = erc.balanceOf(address(this));
        if (bal == 0) revert NoTokenBalance();
        erc.safeTransfer(to, bal);
        emit ERC20Withdraw(erc20, to, bal);
    }

    /* -------------------------------------------------------------------
       Views / helpers
       ------------------------------------------------------------------- */
    function previewTokensForMatic(uint256 maticWei) external view returns (uint256) {
        return (maticWei * maticRate) / MATIC_DECIMALS;
    }

    function previewTokensForUSDT(uint256 usdtBase) external view returns (uint256) {
        return (usdtBase * usdtRate) / USDT_DECIMALS;
    }

    function remainingTokens() external view returns (uint256) {
        return cap > tokensSold ? cap - tokensSold : 0;
    }

    function remainingUSDToGoal() external view returns (uint256) {
        return usdRaised >= goalUSD ? 0 : (goalUSD - usdRaised);
    }

    function isPresaleLive() external view returns (bool) {
        return presaleActive && block.timestamp >= startTime && block.timestamp <= endTime && usdRaised < goalUSD;
    }

    /* -------------------------------------------------------------------
       Fallbacks
       ------------------------------------------------------------------- */
    receive() external payable {}
    fallback() external payable {}
}
