#!/bin/bash

# Script to add liquidity to QuickSwap on Polygon for Porkelon token paired with MATIC (using WMATIC under the hood via addLiquidityETH)
# Requirements: Foundry (cast) installed, Polygon RPC URL, private key with funds/tokens
# Usage: 
# 1. Set environment variables: export PRIVATE_KEY=your_private_key_here
#    export POLYGON_RPC=https://polygon-rpc.com (or your RPC)
# 2. Run: ./add_liquidity.sh <porkelon_address> <amount_porkelon> <amount_matic_wei> <min_amount_porkelon> <min_amount_matic> <deadline_seconds_from_now>
# Example: ./add_liquidity.sh 0xYourPorkelonAddress 1000000000000000000000 1000000000000000000 990000000000000000000 990000000000000000 3600
# (amounts in wei, e.g., 1000 * 10^18 for 1000 tokens if 18 decimals)

# QuickSwap V2 Router address on Polygon
ROUTER=0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff

# Check if cast is installed
if ! command -v cast &> /dev/null; then
    echo "Cast (from Foundry) is not installed. Install Foundry: https://book.getfoundry.sh/install"
    exit 1
fi

# Check required args
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <token_address> <amount_token_desired> <amount_matic_desired> <amount_token_min> <amount_matic_min> <deadline_seconds>"
    exit 1
fi

TOKEN=$1
AMOUNT_TOKEN_DESIRED=$2
AMOUNT_MATIC_DESIRED=$3
AMOUNT_TOKEN_MIN=$4
AMOUNT_MATIC_MIN=$5
DEADLINE=$(($(cast to-uint256 $(date +%s)) + $6))

# Get sender address from private key
SENDER=$(cast wallet address --private-key $PRIVATE_KEY)

echo "Adding liquidity for token $TOKEN with $AMOUNT_MATIC_DESIRED wei MATIC from $SENDER"

# Step 1: Approve the token for the router
echo "Approving $TOKEN for Router..."
cast send $TOKEN "approve(address,uint256)" $ROUTER $AMOUNT_TOKEN_DESIRED \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC

# Step 2: Add liquidity using addLiquidityETH (sends MATIC as value)
echo "Adding liquidity..."
cast send $ROUTER "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)" \
  $TOKEN $AMOUNT_TOKEN_DESIRED $AMOUNT_TOKEN_MIN $AMOUNT_MATIC_MIN $SENDER $DEADLINE \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC --value $AMOUNT_MATIC_DESIRED

echo "Liquidity added! Check on QuickSwap or PolygonScan."
