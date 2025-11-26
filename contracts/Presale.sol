// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // Changed to a stable, recent version for Remix compatibility

/*
 Presale contract:
 - Buyers send USDC (ERC20 with 6 decimals) by calling buy(usdcAmount)
 - They receive PORK tokens minted to their address at the configured rate
 - Rate is expressed as X whole PORK per 1 USDC (eg. 3_000_000)
 - The contract calculates token amounts respecting both tokens' decimals
*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Import standard IERC20
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This interface is used for the PORK token, which must have a mint function.
// We inherit IERC20 to ensure it also has the transfer/balance functions.
interface IMintableERC20 is IERC20 { 
    function mint(address to, uint256 amount) external;
}

// We will use IERC20 for both payment and PORK tokens, and call the decimals() 
// function directly on the IERC20 interface since most tokens implement it.

contract PorkPresale is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Payment token (USDC) and sale token (PORK)
    IERC20 public immutable paymentToken;    // USDC
    IMintableERC20 public immutable porkToken; // PORK - must be mintable by this contract

    // Decimals
    uint8 public immutable paymentDecimals; 
    uint8 public immutable porkDecimals;    

    // Rate: number of WHOLE PORK tokens (not including decimals) per 1 USDC.
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
        
        // Assign tokens
        paymentToken = IERC20(_paymentToken);
        porkToken = IMintableERC20(_porkToken);

        // Fetch decimals (Requires paymentToken to have decimals() implemented)
        paymentDecimals = paymentToken.decimals();
        porkDecimals = porkToken.decimals();

        // Check expected decimals for safety/gas optimization (optional but recommended)
        require(paymentDecimals <= 18, "Payment token decimals too high");
        require(porkDecimals <= 18, "PORK decimals too high");

        porkRate = _porkRate;
        startTimestamp = _startTimestamp;
        maxUSDCToRaise = _maxUSDCToRaise;
    }

    /**
     * @notice Buy PORK using USDC. Caller must have approved USDC to this contract first.
     */
    function buy(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(block.timestamp >= startTimestamp, "Presale not started");
        require(usdcAmount > 0, "Must send USDC");
        require(totalRaised + usdcAmount <= maxUSDCToRaise, "Cap exceeded");

        // Pull USDC from buyer
        paymentToken.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Calculate PORK to mint, taking token decimals into account:
        // tokensToMint = usdcAmount * porkRate * (10^(porkDecimals - paymentDecimals))
        
        uint256 tokensToMint;
        uint256 rateScaled = usdcAmount * porkRate;
        
        if (porkDecimals >= paymentDecimals) {
            uint256 factor = 10 ** (uint256(porkDecimals) - uint256(paymentDecimals));
            tokensToMint = rateScaled * factor;
        } else {
            // Unusual case where PORK decimals < paymentDecimals
            uint256 factor = 10 ** (uint256(paymentDecimals) - uint256(porkDecimals));
            tokensToMint = rateScaled / factor;
        }

        porkToken.mint(msg.sender, tokensToMint);
        totalRaised += usdcAmount;
        emit Bought(msg.sender, usdcAmount, tokensToMint);
    }

    /* ================= Admin Functions (Only Owner) ================= */

    /// @notice Withdraw collected USDC to a target address
    function withdrawUSDC(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        uint256 bal = paymentToken.balanceOf(address(this));
        require(amount <= bal, "Insufficient balance");
        paymentToken.safeTransfer(to, amount);
        // Note: totalRaised is NOT reset here, it tracks the cap, not the contract's balance
        emit Withdrawn(to, amount);
    }

    // [All other admin functions remain the same: setPorkRate, setStartTimestamp, setMaxUSDCToRaise, setPaused, rescueToken]
    // ... (rest of the code)
}
