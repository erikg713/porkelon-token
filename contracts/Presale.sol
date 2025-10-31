// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/*
  Presale contract:
  - Buyers send USDC (ERC20 with 6 decimals) by calling buy(usdcAmount)
  - They receive PORK tokens minted to their address at the configured rate
  - Rate is expressed as X whole PORK per 1 USDC (eg. 3_000_000)
  - The contract calculates token amounts respecting both tokens' decimals
*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 {
    function mint(address to, uint256 amount) external;
    function decimals() external view returns (uint8);
}

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

contract PorkPresale is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Payment token (USDC) and sale token (PORK)
    IERC20 public immutable paymentToken;   // USDC
    IMintableERC20 public immutable porkToken; // PORK - must be mintable by this contract

    // Decimals
    uint8 public immutable paymentDecimals; // likely 6 for USDC on polygon
    uint8 public immutable porkDecimals;    // likely 18

    // Rate: number of WHOLE PORK tokens (not including decimals) per 1 USDC.
    // Example: if porkRate = 3_000_000 then 1 USDC -> 3,000,000 PORK (display units).
    uint256 public porkRate;

    // Presale controls
    uint256 public startTimestamp;
    uint256 public maxUSDCToRaise; // in USDC smallest units (i.e., with paymentDecimals)
    uint256 public totalRaised; // accumulated USDC (with paymentDecimals)
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

        paymentDecimals = IERC20Decimals(_paymentToken).decimals();
        porkDecimals = porkToken.decimals();

        porkRate = _porkRate;
        startTimestamp = _startTimestamp;
        maxUSDCToRaise = _maxUSDCToRaise;
    }

    /**
     * @notice Buy PORK using USDC. Caller must have approved USDC to this contract first.
     * @param usdcAmount the amount of USDC to spend (in USDC smallest units, e.g., 1 USDC = 1_000_000 when paymentDecimals=6)
     */
    function buy(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(block.timestamp >= startTimestamp, "Presale not started");
        require(usdcAmount > 0, "Must send USDC");
        require(totalRaised + usdcAmount <= maxUSDCToRaise, "Cap exceeded");

        // Pull USDC from buyer
        paymentToken.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Calculate PORK to mint, taking token decimals into account:
        // tokensToMint = usdcAmount * porkRate * (10^(porkDecimals - paymentDecimals))
        uint256 factor;
        if (porkDecimals >= paymentDecimals) {
            factor = 10 ** (uint256(porkDecimals) - uint256(paymentDecimals));
            // Beware multiplication overflow: usdcAmount * porkRate * factor fits into 256 bits if sensible inputs
            uint256 tokensToMint = (usdcAmount * porkRate) * factor;
            porkToken.mint(msg.sender, tokensToMint);
            totalRaised += usdcAmount;
            emit Bought(msg.sender, usdcAmount, tokensToMint);
        } else {
            // Unusual case where PORK decimals < paymentDecimals
            // tokensToMint = usdcAmount * porkRate / (10^(paymentDecimals - porkDecimals))
            factor = 10 ** (uint256(paymentDecimals) - uint256(porkDecimals));
            uint256 tokensToMint = (usdcAmount * porkRate) / factor;
            porkToken.mint(msg.sender, tokensToMint);
            totalRaised += usdcAmount;
            emit Bought(msg.sender, usdcAmount, tokensToMint);
        }
    }

    /* ================= Admin Functions ================= */

    /// @notice Withdraw collected USDC to a target address
    function withdrawUSDC(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        uint256 bal = paymentToken.balanceOf(address(this));
        require(amount <= bal, "Insufficient balance");
        paymentToken.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }

    /// @notice Update the porkRate (whole PORK per 1 USDC)
    function setPorkRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "rate>0");
        uint256 old = porkRate;
        porkRate = newRate;
        emit RateUpdated(old, newRate);
    }

    /// @notice Update start timestamp
    function setStartTimestamp(uint256 newStart) external onlyOwner {
        uint256 old = startTimestamp;
        startTimestamp = newStart;
        emit StartUpdated(old, newStart);
    }

    /// @notice Update max USDC to raise (in smallest units)
    function setMaxUSDCToRaise(uint256 newCap) external onlyOwner {
        uint256 old = maxUSDCToRaise;
        maxUSDCToRaise = newCap;
        emit CapUpdated(old, newCap);
    }

    /// @notice Pause/unpause presale
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    /* Emergency: owner can withdraw any ERC20 accidentally sent here (except PORK minting should be left)
       Note: Be careful with allowing arbitrary token withdrawal; restrict usage to owner. */
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        IERC20(token).safeTransfer(to, amount);
    }
}
