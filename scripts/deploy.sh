#!/usr/bin/env bash
set -euo pipefail

# Check for .env file
if [ ! -f .env ]; then
  echo "⚠️ .env file missing! Copy .env.example to .env and fill in values."
  exit 1
fi

NETWORK=${1:-mumbai}
echo "🌐 Deploying Porkelon to $NETWORK"

# Compile contracts
npm run compile

# Run deployment script
npx hardhat run scripts/deploy.js --network $NETWORK --verbose
