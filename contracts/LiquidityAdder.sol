// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityAdder is Ownable {
    IERC20 public token; // PORK token
    address public immutable WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // WMATIC on Polygon
    IUniswapV3Factory public factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984); // QuickSwap V3 Factory
    INonfungiblePositionManager public positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88); // QuickSwap V3 Position Manager
    uint24 public constant POOL_FEE = 3000; // 0.3% fee tier

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
    }

    function addLiquidity(
        uint256 tokenAmount,
        uint256 maticAmount,
        uint160 sqrtPriceX96,
        bool token0IsPORK
    ) external onlyOwner payable {
        require(msg.value >= maticAmount, "Insufficient MATIC sent");
        require(tokenAmount > 0 && maticAmount > 0, "Invalid amounts");

        // Approve tokens and WMATIC
        token.approve(address(positionManager), tokenAmount);
        IERC20(WMATIC).approve(address(positionManager), maticAmount);

        // Sort tokens (PORK/MATIC or MATIC/PORK)
        address token0 = token0IsPORK ? address(token) : WMATIC;
        address token1 = token0IsPORK ? WMATIC : address(token);

        // Create pool if it doesn't exist
        address pool = factory.getPool(token0, token1, POOL_FEE);
        if (pool == address(0)) {
            pool = factory.createPool(token0, token1, POOL_FEE);
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        }

        // Add liquidity
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: POOL_FEE,
            tickLower: -887220, // Wide range for simplicity
            tickUpper: 887220,
            amount0Desired: token0IsPORK ? tokenAmount : maticAmount,
            amount1Desired: token0IsPORK ? maticAmount : tokenAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: owner(),
            deadline: block.timestamp + 3600
        });

        (uint256 tokenId, , , ) = positionManager.mint(params);

        // Refund excess MATIC
        if (msg.value > maticAmount) {
            (bool sent, ) = owner().call{value: msg.value - maticAmount}("");
            require(sent, "Refund failed");
        }
    }

    function withdrawMatic() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No MATIC to withdraw");
        (bool sent, ) = owner().call{value: balance}("");
        require(sent, "MATIC withdrawal failed");
    }

    receive() external payable {}
}
