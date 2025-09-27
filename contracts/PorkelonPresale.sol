// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Presale is Ownable {
    IERC20 public token;
    IERC20 public usdt;
    address public fundsWallet;
    uint256 public maticRate; // Tokens per POL (e.g., 1M PORK per POL)
    uint256 public usdtRate;  // Tokens per USDT
    uint256 public cap;       // Max tokens for presale
    uint256 public tokensSold;
    uint256 public startTime;
    uint256 public endTime;
    bool public presaleActive;

    constructor(
        address _token,
        address _usdt,
        address _fundsWallet,
        uint256 _maticRate,
        uint256 _usdtRate,
        uint256 _cap
    ) Ownable(msg.sender) {
        token = IERC20(_token);
        usdt = IERC20(_usdt);
        fundsWallet = _fundsWallet;
        maticRate = _maticRate;
        usdtRate = _usdtRate;
        cap = _cap;
        presaleActive = false; // Activated when startTime is set
    }

    // Start presale
    function startPresale(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(_startTime >= block.timestamp, "Start time in past");
        require(_endTime > _startTime, "Invalid end time");
        startTime = _startTime;
        endTime = _endTime;
        presaleActive = true;
    }

    // Buy tokens with POL
    function buyWithPOL() external payable {
        require(presaleActive && block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        require(msg.value >= 0.1 ether, "Below minimum purchase");
        require(msg.value <= 10 ether, "Exceeds maximum purchase");
        uint256 tokenAmount = msg.value * maticRate;
        require(tokensSold + tokenAmount <= cap, "Exceeds presale cap");
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens");

        tokensSold += tokenAmount;
        token.transfer(msg.sender, tokenAmount);
        payable(fundsWallet).transfer(msg.value);
    }

    // Buy tokens with USDT
    function buyWithUSDT(uint256 usdtAmount) external {
        require(presaleActive && block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        uint256 tokenAmount = usdtAmount * usdtRate;
        require(tokensSold + tokenAmount <= cap, "Exceeds presale cap");
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens");

        tokensSold += tokenAmount;
        usdt.transferFrom(msg.sender, fundsWallet, usdtAmount);
        token.transfer(msg.sender, tokenAmount);
    }

    // End presale and transfer remaining tokens
    function endPresale() external onlyOwner {
        presaleActive = false;
        uint256 remainingTokens = token.balanceOf(address(this));
        if (remainingTokens > 0) {
            token.transfer(owner(), remainingTokens);
        }
    }
}
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PorkelonPresale
 * @dev Manages PORK token presale with MATIC and USDT payments.
 */
contract PorkelonPresale is OwnableUpgradeable, ReentrancyGuardUpgradeable {
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the presale contract.
     * @param _token PORK token address.
     * @param _usdt USDT token address.
     * @param _tokenPriceMatic Tokens per MATIC.
     * @param _tokenPriceUsdt Tokens per USDT.
     * @param _minPurchase Minimum purchase amount.
     * @param _maxPurchase Maximum purchase amount.
     * @param _startTime Presale start timestamp.
     * @param _endTime Presale end timestamp.
     * @param _cap Total PORK tokens available.
     */
    function initialize(
        IERC20 _token,
        IERC20 _usdt,
        uint256 _tokenPriceMatic,
        uint256 _tokenPriceUsdt,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _cap
    ) external initializer {
        require(address(_token) != address(0), "PorkelonPresale: Invalid token address");
        require(address(_usdt) != address(0), "PorkelonPresale: Invalid USDT address");
        require(_tokenPriceMatic > 0, "PorkelonPresale: Invalid MATIC price");
        require(_tokenPriceUsdt > 0, "PorkelonPresale: Invalid USDT price");
        require(_minPurchase > 0, "PorkelonPresale: Invalid min purchase");
        require(_maxPurchase >= _minPurchase, "PorkelonPresale: Max < min purchase");
        require(_startTime > block.timestamp, "PorkelonPresale: Start time in past");
        require(_endTime > _startTime, "PorkelonPresale: End time <= start");
        require(_cap > 0, "PorkelonPresale: Invalid cap");

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

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

    /**
     * @dev Buy PORK tokens with MATIC.
     */
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

    /**
     * @dev Buy PORK tokens with USDT.
     * @param usdtAmount Amount of USDT to spend.
     */
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

    /**
     * @dev Updates funds wallet.
     * @param _newWallet New funds wallet address.
     */
    function setFundsWallet(address _newWallet) external onlyOwner {
        require(_newWallet != address(0), "PorkelonPresale: Invalid wallet");
        address oldWallet = fundsWallet;
        fundsWallet = _newWallet;
        emit FundsWalletUpdated(oldWallet, _newWallet);
    }

    /**
     * @dev Withdraws remaining tokens after presale.
     */
    function withdrawRemainingTokens() external onlyOwner {
        require(block.timestamp > endTime, "PorkelonPresale: Still active");
        uint256 remaining = token.balanceOf(address(this));
        require(remaining > 0, "PorkelonPresale: No tokens to withdraw");
        require(token.transfer(owner(), remaining), "PorkelonPresale: Token transfer failed");
        emit TokensWithdrawn(owner(), remaining);
    }
}
