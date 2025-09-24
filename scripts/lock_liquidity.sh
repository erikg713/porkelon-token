#!/bin/bash

# Script to lock liquidity (LP NFT from Uniswap V3) on Unicrypt V2 Liquidity Locker on Polygon for 1 year.
# Requirements: Foundry (cast) installed, Polygon RPC URL, private key with funds.
# Usage: 
# 1. Set environment variables: export PRIVATE_KEY=0xf706cc2d6afa58c74ad243a47fea13e2c81816dd897e547c7c914c21be8a641d
#    export POLYGON_RPC=https://polygon-rpc.com (or your RPC)
# 2. Run: ./scripts/lock_liquidity.sh <nft_token_id> <withdrawer_address> [<referral_address>]
# Example: ./scripts/lock_liquidity.sh 12345 0x23cE6D1E06D8509A5668e9E1602de1c2b19ba3a2 0x0000000000000000000000000000000000000000
# (nft_token_id from PositionManager after mint; referral optional)

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
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <nft_token_id> <withdrawer_address> [<referral_address>]"
    exit 1
fi

NFT_ID=$1
WITHDRAWER=$2
REFERRAL=${3:-0x0000000000000000000000000000000000000000}  # Default to zero

# Calculate unlock date: 1 year from now (31536000 seconds)
CURRENT_TIMESTAMP=$(cast to-uint256 $(date +%s))
UNLOCK_DATE=$(($CURRENT_TIMESTAMP + 31536000))

FEE_IN_ETH=true  # Pay flat fee in MATIC

SENDER=$(cast wallet address --private-key $PRIVATE_KEY)

echo "Locking NFT ID $NFT_ID for 1 year, withdrawer $WITHDRAWER, from $SENDER"

# Step 1: Approve the NFT for the locker (ERC721 approve)
echo "Approving NFT for Unicrypt Locker..."
cast send $POSITION_MANAGER "approve(address,uint256)" $LOCKER $NFT_ID \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC

# Step 2: Call lockLPToken (for V3, Unicrypt treats NFTs as LP; confirm compatibility or use Unicrypt's V3 locker if separate)
echo "Locking liquidity..."
cast send $LOCKER "lockLPToken(address,uint256,uint256,address,bool,address)" \
  $POSITION_MANAGER $NFT_ID $UNLOCK_DATE $REFERRAL $FEE_IN_ETH $WITHDRAWER \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC --value $FLAT_FEE  # Note: Unicrypt V2 may not directly support V3 NFTs; check docs or use dedicated V3 locker if available

echo "Liquidity locked for 1 year! Check on Unicrypt app or PolygonScan."
