#!/bin/bash

# Environment variables - SET THESE BEFORE RUNNING!
export PRIVATE_KEY="0xYourLiquidityWalletPrivateKeyHere"  # Never share this!
export RPC_URL="https://polygon-rpc.com"  # Polygon mainnet RPC
export PORKELON_ADDRESS="0xYourDeployedPorkelonContractAddressHere"
export WMATIC_ADDRESS="0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
export QUICKSWAP_ROUTER="0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff"
export AMOUNT_PORK_DESIRED="40000000000000000000000000000"  # 40 billion PORK (40e9 * 1e18 for 18 decimals)
export AMOUNT_WMATIC_DESIRED="10000000000000000000"  # Example: 10 WMATIC (10e18 wei); adjust based on your funding
export AMOUNT_PORK_MIN="32000000000000000000000000000"  # Min PORK to add (e.g., 80% of desired to allow slippage)
export AMOUNT_WMATIC_MIN="8000000000000000000"  # Min WMATIC (e.g., 80% of desired)
export DEADLINE=$(($(date +%s) + 3600))  # 1 hour from now (Unix timestamp)
export RECIPIENT="0xYourLiquidityWalletAddressHere"  # Where to send LP tokens (your wallet)

# Step 1: Approve PORK for Router
echo "Approving PORK for QuickSwap Router..."
cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL $PORKELON_ADDRESS "approve(address,uint256)" $QUICKSWAP_ROUTER $AMOUNT_PORK_DESIRED

# Step 2: Approve WMATIC for Router (if not already)
echo "Approving WMATIC for QuickSwap Router..."
cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL $WMATIC_ADDRESS "approve(address,uint256)" $QUICKSWAP_ROUTER $AMOUNT_WMATIC_DESIRED

# Step 3: Add Liquidity
echo "Adding Liquidity..."
cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL $QUICKSWAP_ROUTER "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)" \
  $PORKELON_ADDRESS \
  $WMATIC_ADDRESS \
  $AMOUNT_PORK_DESIRED \
  $AMOUNT_WMATIC_DESIRED \
  $AMOUNT_PORK_MIN \
  $AMOUNT_WMATIC_MIN \
  $RECIPIENT \
  $DEADLINE

echo "Liquidity added! Check your wallet for LP tokens, then lock them on Unicrypt."
