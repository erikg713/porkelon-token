// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Presale contract (GAS-OPTIMIZED):
// - Buyers send USDC (ERC20 with 6 decimals) by calling buy(usdcAmount)
// - They receive PORK tokens minted at the configured rate
// - Rate = X whole PORK per 1 USDC (e.g. 3_000_000)
// - All decimal handling is precomputed in constructor → zero runtime cost in buy()

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 is IERC20Metadata { 
    function mint(address to, uint256 amount) external;
}

contract PorkPresale is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Payment token (USDC) and sale token (PORK)
    IERC20 public immutable paymentToken;
    IMintableERC20 public immutable porkToken;

    // Decimals (kept for transparency / frontend)
    uint8 public immutable paymentDecimals; 
    uint8 public immutable porkDecimals;    

    // Rate: whole PORK tokens per 1 USDC
    uint256 public porkRate;

    // Precomputed scaling (BIG GAS WIN for every buy())
    uint256 public immutable scalingFactor;   // 10 ** |porkDecimals - paymentDecimals|
    bool public immutable needsDivision;      // true only if porkDecimals < paymentDecimals (very rare)

    // Presale controls
    uint256 public startTimestamp;
    uint256 public maxUSDCToRaise;
    uint256 public totalRaised;
    bool public paused;

    event Bought(address indexed buyer, uint256 usdcAmount, uint256 porkAmount);
    event Withdrawn(address indexed to, uint256 amount);
    event RateUpdated(uint256 oldRate, uint256 newRate);
    event StartUpdated(uint256 oldStart, uint256 newStart);
    event CapUpdated(uint256 oldCap, uint256 newCap);
    event Paused(bool isPaused);

    modifier whenNotPaused() {
        require(!paused, "Presale paused");
        _;
    }

    constructor(
        address _paymentToken,
        address _porkToken,
        uint256 _porkRate,
        uint256 _startTimestamp,
        uint256 _maxUSDCToRaise
    ) {
        require(_paymentToken != address(0), "paymentToken=0");
        require(_porkToken != address(0), "porkToken=0");
        require(_porkRate > 0, "rate>0");
        
        paymentToken = IERC20(_paymentToken);
        porkToken = IMintableERC20(_porkToken);

        // Fetch decimals once
        paymentDecimals = IERC20Metadata(_paymentToken).decimals();
        porkDecimals = IERC20Metadata(_porkToken).decimals();

        require(paymentDecimals <= 18, "Payment decimals too high");
        require(porkDecimals <= 18, "PORK decimals too high");

        // === GAS OPTIMIZATION: Precompute decimal scaling (done only once at deploy) ===
        uint256 _scalingFactor;
        bool _needsDivision;
        if (porkDecimals >= paymentDecimals) {
            uint8 diff = porkDecimals - paymentDecimals;
            _scalingFactor = 10 ** uint256(diff);   // max 1e18, fits uint256
            _needsDivision = false;
        } else {
            uint8 diff = paymentDecimals - porkDecimals;
            _scalingFactor = 10 ** uint256(diff);
            _needsDivision = true;
        }
        scalingFactor = _scalingFactor;
        needsDivision = _needsDivision;
        // ============================================================================

        porkRate = _porkRate;
        startTimestamp = _startTimestamp;
        maxUSDCToRaise = _maxUSDCToRaise;
    }

    /**
     * @notice Buy PORK using USDC. Caller must approve USDC first.
     * @dev Gas-optimized: decimal scaling is precomputed → no 10** or branching at runtime.
     */
    function buy(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(block.timestamp >= startTimestamp, "Presale not started");
        require(usdcAmount > 0, "Must send USDC");
        require(totalRaised + usdcAmount <= maxUSDCToRaise, "Cap exceeded");

        // Pull USDC
        paymentToken.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // === Gas-optimized token calculation (no if, no exponentiation) ===
        uint256 rateScaled = usdcAmount * porkRate;
        uint256 tokensToMint = needsDivision 
            ? rateScaled / scalingFactor 
            : rateScaled * scalingFactor;
        // =================================================================

        porkToken.mint(msg.sender, tokensToMint);
        totalRaised += usdcAmount;

        emit Bought(msg.sender, usdcAmount, tokensToMint);
    }

    /* ================= Admin Functions (Only Owner) ================= */

    function withdrawUSDC(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        uint256 bal = paymentToken.balanceOf(address(this));
        require(amount <= bal, "Insufficient balance");
        paymentToken.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }

    function setPorkRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0, "rate>0");
        uint256 oldRate = porkRate;
        porkRate = _newRate;
        emit RateUpdated(oldRate, _newRate);
    }

    function setStartTimestamp(uint256 _newStart) external onlyOwner {
        uint256 oldStart = startTimestamp;
        startTimestamp = _newStart;
        emit StartUpdated(oldStart, _newStart);
    }

    function setMaxUSDCToRaise(uint256 _newCap) external onlyOwner {
        uint256 oldCap = maxUSDCToRaise;
        maxUSDCToRaise = _newCap;
        emit CapUpdated(oldCap, _newCap);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    function rescueToken(IERC20 token, address to, uint256 amount) external onlyOwner {
        require(address(token) != address(0), "token=0");
        require(to != address(0), "to=0");
        token.safeTransfer(to, amount);
    }
}
