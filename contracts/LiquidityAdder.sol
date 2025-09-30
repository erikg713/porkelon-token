// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// Interface for WMATIC deposit function
interface IWMATIC is IERC20 {
    function deposit() external payable;
}

contract LiquidityAdder is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token; // PORK token
    
    // CORRECTED: Addresses for Polygon Mainnet
    address public immutable WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    IUniswapV3Factory public immutable factory = IUniswapV3Factory(0x411b0fAcC3489691f28ad58c47006AF5E3Ab3A28); // QuickSwap V3 Factory on Polygon
    INonfungiblePositionManager public immutable positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    
    uint24 public constant POOL_FEE = 3000; // 0.3% fee tier

    event LiquidityAdded(uint256 tokenId, address pool, uint256 tokenAmount, uint256 maticAmount);
    event MaticWithdrawn(address indexed owner, uint256 amount);

    constructor(address _tokenAddress) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = IERC20(_tokenAddress);
    }

    receive() external payable {}

    function addLiquidity(
        uint256 tokenAmount,
        uint256 maticAmount,
        uint160 sqrtPriceX96,
        bool token0IsPORK,
        int24 tickLower,
        int24 tickUpper
    ) external onlyOwner payable returns (uint256 tokenId) {
        require(msg.value >= maticAmount, "Insufficient MATIC sent");
        require(tokenAmount > 0 && maticAmount > 0, "Invalid amounts");
        require(tickLower < tickUpper, "Invalid tick range");

        // Fund this contract with PORK before calling this function
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient PORK balance in contract");

        // --- FIXED: Wrap MATIC to WMATIC ---
        IWMATIC(WMATIC).deposit{value: maticAmount}();
        require(IWMATIC(WMATIC).balanceOf(address(this)) >= maticAmount, "WMATIC wrapping failed");

        // Approve tokens for the Position Manager
        token.safeApprove(address(positionManager), tokenAmount);
        IWMATIC(WMATIC).safeApprove(address(positionManager), maticAmount);

        // Determine token order
        address token0 = token0IsPORK ? address(token) : WMATIC;
        address token1 = token0IsPORK ? WMATIC : address(token);

        // Check or create pool
        address pool = factory.getPool(token0, token1, POOL_FEE);
        if (pool == address(0)) {
            pool = factory.createPool(token0, token1, POOL_FEE);
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        }

        // Mint liquidity position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: POOL_FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: token0IsPORK ? tokenAmount : maticAmount,
            amount1Desired: token0IsPORK ? maticAmount : tokenAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: owner(), // The LP NFT will be sent to the contract owner
            deadline: block.timestamp + 600
        });

        (tokenId, , , ) = positionManager.mint(params);
        emit LiquidityAdded(tokenId, pool, tokenAmount, maticAmount);

        // Refund any excess MATIC sent with the transaction
        if (msg.value > maticAmount) {
            (bool sent, ) = owner().call{value: msg.value - maticAmount}("");
            require(sent, "MATIC refund failed");
        }
    }

    // Safety function to withdraw any leftover MATIC from this contract
    function withdrawMatic() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No MATIC to withdraw");
        (bool sent, ) = owner().call{value: balance}("");
        require(sent, "MATIC withdrawal failed");
        emit MaticWithdrawn(owner(), balance);
    }
    
    // Utility to transfer the LP NFT from the owner to another address
    function transferPosition(uint256 tokenId, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        positionManager.safeTransferFrom(owner(), to, tokenId);
    }
}
