// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityAdder is Ownable {
    IERC20 public immutable token; // PORK token
    address public immutable WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // WMATIC on Polygon
    IUniswapV3Factory public immutable factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984); // QuickSwap V3 Factory
    INonfungiblePositionManager public immutable positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88); // QuickSwap V3 Position Manager
    uint24 public constant POOL_FEE = 3000; // 0.3% fee tier

    event LiquidityAdded(uint256 tokenId, address pool, uint256 tokenAmount, uint256 maticAmount);
    event MaticWithdrawn(address indexed owner, uint256 amount);

    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
    }

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
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient PORK balance");
        require(address(this).balance >= maticAmount, "Insufficient MATIC balance");

        // Approve tokens and WMATIC
        require(token.approve(address(positionManager), tokenAmount), "PORK approval failed");
        require(IERC20(WMATIC).approve(address(positionManager), maticAmount), "WMATIC approval failed");

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
            recipient: owner(),
            deadline: block.timestamp + 3600
        });

        (tokenId, , , ) = positionManager.mint(params);
        emit LiquidityAdded(tokenId, pool, tokenAmount, maticAmount);

        // Refund excess MATIC
        if (msg.value > maticAmount) {
            (bool sent, ) = owner().call{value: msg.value - maticAmount}("");
            require(sent, "MATIC refund failed");
        }
    }

    function withdrawMatic() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No MATIC to withdraw");
        (bool sent, ) = owner().call{value: balance}("");
        require(sent, "MATIC withdrawal failed");
        emit MaticWithdrawn(owner(), balance);
    }

    function transferPosition(uint256 tokenId, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        positionManager.safeTransferFrom(owner(), to, tokenId);
    }

    receive() external payable {}
}
