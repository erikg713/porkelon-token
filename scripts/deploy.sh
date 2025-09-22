#!/usr/bin/env bash
set -euo pipefail

NETWORK=${1:-mumbai} # usage: ./scripts/deploy.sh mumbai  OR polygon
echo "Deploying to network: $NETWORK"

npm run compile
npx hardhat run scripts/deploy.js --network $NETWORK
