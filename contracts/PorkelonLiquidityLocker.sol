// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IQuickSwapV3PositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    function mint(MintParams calldata params) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

contract PorkelonLiquidityLocker is Ownable, Pausable {
    IERC20 public immutable token; // PORK
    IERC20 public immutable maticToken; // WMATIC
    address public immutable beneficiary; // Fallback (e.g., multisig)
    uint256 public immutable lockAmount; // 40B PORK
    uint256 public releaseTime;

    uint256 public constant RELEASE_DELAY = 1 days;
    uint256 public proposedReleaseTimestamp;
    address public proposedRecipient;

    // QuickSwap V3 (Polygon mainnet)
    address public constant QUICKSWAP_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; // Update with actual address
    uint24 public constant POOL_FEE = 3000; // 0.3% fee tier

    event TokensReleased(address indexed recipient, uint256 amount);
    event ReleaseProposed(address indexed recipient, uint256 timestamp);
    event LiquidityAdded(uint256 tokenId, uint256 liquidity);

    constructor(
        IERC20 _token,
        address _beneficiary,
        uint256 _lockAmount,
        IERC20 _maticToken // WMATIC: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
    ) Ownable(msg.sender) {
        require(address(_token) != address(0), "Invalid token address");
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_lockAmount > 0, "Invalid lock amount");
        require(address(_maticToken) != address(0), "Invalid MATIC token");
        require(_token.balanceOf(address(this)) >= _lockAmount, "Insufficient token balance");

        token = _token;
        beneficiary = _beneficiary;
        lockAmount = _lockAmount;
        maticToken = _maticToken;
        releaseTime = block.timestamp + 365 days;
    }

    function proposeRelease(address recipient) external onlyOwner whenNotPaused {
        require(recipient != address(0), "Invalid recipient");
        proposedRecipient = recipient;
        proposedReleaseTimestamp = block.timestamp;
        emit ReleaseProposed(recipient, block.timestamp);
    }

    function release() external onlyOwner whenNotPaused {
        require(proposedReleaseTimestamp > 0 && block.timestamp >= proposedReleaseTimestamp + RELEASE_DELAY, "Timelock not elapsed");
        require(block.timestamp >= releaseTime, "Tokens still locked");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens to release");
        require(token.transfer(proposedRecipient, amount), "Transfer failed");
        emit TokensReleased(proposedRecipient, amount);
        proposedReleaseTimestamp = 0;
        proposedRecipient = address(0);
    }

    function releaseToPool(
        uint256 porkAmount,
        int24 tickLower,
        int24 tickUpper,
        uint256 deadline,
        uint256 amount0Min,
        uint256 amount1Min
    ) external onlyOwner whenNotPaused {
        require(block.timestamp >= releaseTime, "Tokens still locked");
        require(porkAmount > 0 && porkAmount <= token.balanceOf(address(this)), "Invalid PORK amount");
        uint256 maticNeeded = (porkAmount / 50_000) + (porkAmount % 50_000 > 0 ? 1 : 0); // Ceiling for 50k:1
        require(maticToken.balanceOf(address(this)) >= maticNeeded, "Insufficient MATIC");

        token.approve(QUICKSWAP_POSITION_MANAGER, porkAmount);
        maticToken.approve(QUICKSWAP_POSITION_MANAGER, maticNeeded);

        IQuickSwapV3PositionManager.MintParams memory params = IQuickSwapV3PositionManager.MintParams({
            token0: address(maticToken),
            token1: address(token),
            fee: POOL_FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: maticNeeded,
            amount1Desired: porkAmount,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: address(this), // Holds LP NFT
            deadline: deadline
        });

        (uint256 tokenId, uint128 liquidity, , ) = IQuickSwapV3PositionManager(QUICKSWAP_POSITION_MANAGER).mint(params);
        emit LiquidityAdded(tokenId, uint256(liquidity));
        emit TokensReleased(QUICKSWAP_POSITION_MANAGER, porkAmount + maticNeeded);
    }

    function releasePartial(uint256 amount) external onlyOwner whenNotPaused {
        require(block.timestamp >= releaseTime, "Tokens still locked");
        require(amount > 0 && amount <= token.balanceOf(address(this)), "Invalid amount");
        require(token.transfer(beneficiary, amount), "Transfer failed");
        emit TokensReleased(beneficiary, amount);
    }

    function releaseToStaking(address stakingContract) external onlyOwner whenNotPaused {
        require(stakingContract != address(0), "Invalid staking contract");
        require(block.timestamp >= releaseTime, "Tokens still locked");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens to release");
        require(token.approve(stakingContract, amount), "Approval failed");
        emit TokensReleased(stakingContract, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {} // Accept MATIC for pool funding
}
