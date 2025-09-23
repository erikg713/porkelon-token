#!/bin/bash

# Script to lock liquidity (LP tokens) on Unicrypt V2 Liquidity Locker on Polygon for 1 year.
# Requirements: Foundry (cast) installed, Polygon RPC URL, private key with funds/LP tokens.
# Usage: 
# 1. Set environment variables: export PRIVATE_KEY=your_private_key_here
#    export POLYGON_RPC=https://polygon-rpc.com (or your RPC)
# 2. Run: ./scripts/lock_liquidity.sh <lp_token_address> <amount_to_lock> <withdrawer_address> [<referral_address>]
# Example: ./scripts/lock_liquidity.sh 0xYourLPPairAddress 1000000000000000000000 0xYourWithdrawerAddress 0x0000000000000000000000000000000000000000
# (amount in wei, e.g., full LP balance; referral optional, defaults to zero address)

# Unicrypt V2 Liquidity Locker address on Polygon
LOCKER=0xadb2437e6f65682b85f814fbc12fec0508a7b1d0

# Flat fee in MATIC (100 MATIC = 100e18 wei)
FLAT_FEE=100000000000000000000

# Check if cast is installed
if ! command -v cast &> /dev/null; then
    echo "Cast (from Foundry) is not installed. Install Foundry: https://book.getfoundry.sh/install"
    exit 1
fi

# Check required args
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <lp_token_address> <amount_to_lock> <withdrawer_address> [<referral_address>]"
    exit 1
fi

LP_TOKEN=$1
AMOUNT=$2
WITHDRAWER=$3
REFERRAL=${4:-0x0000000000000000000000000000000000000000}  # Default to zero if not provided

# Calculate unlock date: 1 year from now (31536000 seconds)
CURRENT_TIMESTAMP=$(cast to-uint256 $(date +%s))
UNLOCK_DATE=$(($CURRENT_TIMESTAMP + 31536000))

# Fee in ETH (MATIC on Polygon): Assume no referral discount for simplicity; if referral, fee may be lower, but script sends full 100 MATIC (excess refunded if applicable)
FEE_IN_ETH=true  # Pay flat fee in MATIC

# Get sender address
SENDER=$(cast wallet address --private-key $PRIVATE_KEY)

echo "Locking $AMOUNT wei of LP token $LP_TOKEN for 1 year, withdrawer $WITHDRAWER, from $SENDER"

# Step 1: Approve the LP token for the locker
echo "Approving LP token for Unicrypt Locker..."
cast send $LP_TOKEN "approve(address,uint256)" $LOCKER $AMOUNT \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC

# Step 2: Call lockLPToken with fee
echo "Locking liquidity..."
cast send $LOCKER "lockLPToken(address,uint256,uint256,address,bool,address)" \
  $LP_TOKEN $AMOUNT $UNLOCK_DATE $REFERRAL $FEE_IN_ETH $WITHDRAWER \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC --value $FLAT_FEE

echo "Liquidity locked for 1 year! Check on Unicrypt app or PolygonScan for the lock details."
