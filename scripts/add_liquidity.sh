#!/bin/bash

# Script to add liquidity to Uniswap V3 on Polygon for Porkelon token paired with WMATIC.
# Requirements: Foundry (cast) installed, Polygon RPC URL, private key with funds/tokens.
# Usage: 
# 1. Set environment variables: export PRIVATE_KEY=your_private_key_here
#    export POLYGON_RPC=https://polygon-rpc.com (or your RPC)
# 2. Run: ./add_liquidity.sh
# Assumes pool creation if not exists, with initial price 1 WMATIC = 10000 PORK (adjust SQRT_PRICE if needed).
# Adds liquidity in a range: tickLower to tickUpper (example ±10% around initial; adjust).

# Uniswap V3 addresses on Polygon
FACTORY=0x1F98431c8aD98523631AE4a59f267346ea31F984
POSITION_MANAGER=0xC36442b4a4522E871399CD717aBDD847Ab11FE88
WMATIC=0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270

# Set these
PORK=0x3acc6396458daAf9F0b0545a4752591880eF6e28  # Your deployed Porkelon address
FEE=3000  # 0.3% fee tier (500=0.05%, 10000=1%)
AMOUNT_PORK_DESIRED=40000000000000000000000000000  # 40B PORK (40e9 * 1e18)
AMOUNT_WMATIC_DESIRED=10000000000000000000  # Example 10 WMATIC
AMOUNT_PORK_MIN=1.0  # Slippage min (adjust)
AMOUNT_WMATIC_MIN=0
DEADLINE=$(($(date +%s) + 3600))  # 1 hour
RECIPIENT=0x23cE6D1E06D8509A5668e9E1602de1c2b19ba3a2

# Initial sqrtPriceX96 for pool init (example: if WMATIC < PORK, price = PORK/WMATIC = 10000, sqrt=100, *2^96)
SQRT_PRICE=7922816251426433759354395033600  # For price=10000; use 792281625142643392428113920 for inverse if PORK < WMATIC

# Tick range for position (example full range-ish; calculate based on price: tick = 460363 * ln(price) or use tools)
TICK_LOWER=-887220  # Wide range; adjust for concentrated
TICK_UPPER=887220

# Check if cast is installed
if ! command -v cast &> /dev/null; then
    echo "Cast (from Foundry) is not installed. Install Foundry: https://book.getfoundry.sh/install"
    exit 1
fi

# Get sender
SENDER=$(cast wallet address --private-key $PRIVATE_KEY)

# Determine token0 and token1 (sorted by address)
if [ $(cast to-uint256 $WMATIC) -lt $(cast to-uint256 $PORK) ]; then
    TOKEN0=$WMATIC
    TOKEN1=$PORK
    AMOUNT0_DESIRED=$AMOUNT_WMATIC_DESIRED
    AMOUNT1_DESIRED=$AMOUNT_PORK_DESIRED
    AMOUNT0_MIN=$AMOUNT_WMATIC_MIN
    AMOUNT1_MIN=$AMOUNT_PORK_MIN
    # SQRT_PRICE for price = TOKEN1/TOKEN0 = PORK/WMATIC = 10000
    SQRT_PRICE=7922816251426433759354395033600
else
    TOKEN0=$PORK
    TOKEN1=$WMATIC
    AMOUNT0_DESIRED=$AMOUNT_PORK_DESIRED
    AMOUNT1_DESIRED=$AMOUNT_WMATIC_DESIRED
    AMOUNT0_MIN=$AMOUNT_PORK_MIN
    AMOUNT1_MIN=$AMOUNT_WMATIC_MIN
    # SQRT_PRICE for price = TOKEN1/TOKEN0 = WMATIC/PORK = 0.0001
    SQRT_PRICE=792281625142643392428113920
fi

echo "Adding V3 liquidity for $PORK / $WMATIC from $SENDER"

# Step 1: Approve tokens to Position Manager
echo "Approving $PORK..."
cast send $PORK "approve(address,uint256)" $POSITION_MANAGER $AMOUNT_PORK_DESIRED \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC

echo "Approving $WMATIC..."
cast send $WMATIC "approve(address,uint256)" $POSITION_MANAGER $AMOUNT_WMATIC_DESIRED \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC

# Step 2: Check if pool exists
POOL=$(cast call $FACTORY "getPool(address,address,uint24)" $TOKEN0 $TOKEN1 $FEE --rpc-url $POLYGON_RPC)

if [ "$POOL" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Creating pool..."
    cast send $FACTORY "createPool(address,address,uint24)" $TOKEN0 $TOKEN1 $FEE \
      --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC

    POOL=$(cast call $FACTORY "getPool(address,address,uint24)" $TOKEN0 $TOKEN1 $FEE --rpc-url $POLYGON_RPC)

    echo "Initializing pool with sqrtPriceX96 $SQRT_PRICE..."
    cast send $POOL "initialize(uint160)" $SQRT_PRICE \
      --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC
fi

# Step 3: Mint position (add liquidity)
# MintParams struct: token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, recipient, deadline
echo "Minting position..."
cast send $POSITION_MANAGER "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))" \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_LOWER,$TICK_UPPER,$AMOUNT0_DESIRED,$AMOUNT1_DESIRED,$AMOUNT0_MIN,$AMOUNT1_MIN,$RECIPIENT,$DEADLINE)" \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC --value 0  # No value if no native, but WMATIC is ERC20

# Optional: Call refundETH if native sent, but not needed here

echo "Liquidity added to Uniswap V3! Check your wallet for the NFT position token, then lock it on Unicrypt if desired."
