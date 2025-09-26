#!/bin/bash
# scripts/lock_liquidity.sh
set -e

NETWORK=${1:-amoy}
LP_TOKEN_ADDRESS=${LP_TOKEN_ADDRESS:-$(grep LP_TOKEN_ADDRESS .env | cut -d '=' -f2)}
UNICRYPT_ADDRESS="0x6633d1C4DB4dB0D3B9fC690B0C6b7B8c4D2A5e5a"
LIQUIDITY_WALLET_PRIVATE_KEY=$(grep PRIVATE_KEY .env | head -1 | cut -d '=' -f2)

if [ -z "$LIQUIDITY_WALLET_PRIVATE_KEY" ]; then
  echo "Error: LIQUIDITY_WALLET_PRIVATE_KEY not set in .env"
  exit 1
fi

if [ -z "$LP_TOKEN_ADDRESS" ]; then
  echo "Error: LP_TOKEN_ADDRESS not set in .env"
  exit 1
fi

cat > scripts/temp_lock_liquidity.js << EOL
const { ethers } = require("hardhat");
async function main() {
  const wallet = new ethers.Wallet("${LIQUIDITY_WALLET_PRIVATE_KEY}", ethers.provider);
  const lpToken = await ethers.getContractAt("IERC20", "${LP_TOKEN_ADDRESS}", wallet);
  const unicrypt = await ethers.getContractAt("IUnicryptLocker", "${UNICRYPT_ADDRESS}", wallet);
  const lpAmount = await lpToken.balanceOf("${process.env.LIQUIDITY_WALLET}");
  await lpToken.approve("${UNICRYPT_ADDRESS}", lpAmount);
  const tx = await unicrypt.lockLPToken(
    "${LP_TOKEN_ADDRESS}",
    lpAmount,
    Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
    false,
    "${process.env.LIQUIDITY_WALLET}"
  );
  console.log("Liquidity locked:", tx.hash);
  await tx.wait();
}
main().catch(error => { console.error(error); process.exit(1); });
EOL

npx hardhat run scripts/temp_lock_liquidity.js --network $NETWORK
rm scripts/temp_lock_liquidity.js
