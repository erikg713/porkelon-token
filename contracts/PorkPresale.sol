// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 {
    function mint(address to, uint256 amount) external;
    function decimals() external view returns (uint8);
}

interface IERC20Decimals {
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint256);
}

contract PorkPresale is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable paymentToken;   // USDC
    IMintableERC20 public immutable porkToken; // PORK

    uint8 public immutable paymentDecimals;
    uint8 public immutable porkDecimals;

    uint256 public porkRate; // whole PORK per 1 USDC (e.g., 3_000_000)
    uint256 public startTimestamp;
    uint256 public maxUSDCToRaise; // in USDC smallest units (6 decimals)
    uint256 public totalRaised; // in USDC smallest units
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

    function buy(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(block.timestamp >= startTimestamp, "Presale not started");
        require(usdcAmount > 0, "Must send USDC");
        require(totalRaised + usdcAmount <= maxUSDCToRaise, "Cap exceeded");

        paymentToken.safeTransferFrom(msg.sender, address(this), usdcAmount);

        uint256 tokensToMint;
        if (porkDecimals >= paymentDecimals) {
            uint256 factor = 10 ** (uint256(porkDecimals) - uint256(paymentDecimals));
            tokensToMint = (usdcAmount * porkRate) * factor;
        } else {
            uint256 factor = 10 ** (uint256(paymentDecimals) - uint256(porkDecimals));
            tokensToMint = (usdcAmount * porkRate) / factor;
        }

        porkToken.mint(msg.sender, tokensToMint);
        totalRaised += usdcAmount;

        emit Bought(msg.sender, usdcAmount, tokensToMint);
    }

    function withdrawUSDC(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        uint256 bal = paymentToken.balanceOf(address(this));
        require(amount <= bal, "Insufficient balance");
        paymentToken.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }

    function setPorkRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "rate>0");
        uint256 old = porkRate;
        porkRate = newRate;
        emit RateUpdated(old, newRate);
    }

    function setStartTimestamp(uint256 newStart) external onlyOwner {
        uint256 old = startTimestamp;
        startTimestamp = newStart;
        emit StartUpdated(old, newStart);
    }

    function setMaxUSDCToRaise(uint256 newCap) external onlyOwner {
        uint256 old = maxUSDCToRaise;
        maxUSDCToRaise = newCap;
        emit CapUpdated(old, newCap);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        IERC20(token).safeTransfer(to, amount);
    }
}
