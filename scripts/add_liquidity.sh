#!/bin/bash
# scripts/add_liquidity.sh
set -e

NETWORK=${1:-amoy}
PORK_ADDRESS=$(jq -r '.Porkelon' deployments.json)
ROUTER_ADDRESS="0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff" # QuickSwap
LIQUIDITY_WALLET_PRIVATE_KEY=$(grep PRIVATE_KEY .env | head -1 | cut -d '=' -f2)
AMOUNT_TOKEN=$(npx hardhat eval "ethers.parseEther('40000000000')") # 40B PORK
AMOUNT_ETH=$(npx hardhat eval "ethers.parseEther('100')") # Adjust MATIC

if [ -z "$LIQUIDITY_WALLET_PRIVATE_KEY" ]; then
  echo "Error: LIQUIDITY_WALLET_PRIVATE_KEY not set in .env"
  exit 1
fi

cat > scripts/temp_add_liquidity.js << EOL
const { ethers } = require("hardhat");
async function main() {
  const wallet = new ethers.Wallet("${LIQUIDITY_WALLET_PRIVATE_KEY}", ethers.provider);
  const porkelon = await ethers.getContractAt("Porkelon", "${PORK_ADDRESS}", wallet);
  const router = await ethers.getContractAt("IUniswapV2Router02", "${ROUTER_ADDRESS}", wallet);
  await porkelon.approve("${ROUTER_ADDRESS}", "${AMOUNT_TOKEN}");
  const tx = await router.addLiquidityETH(
    "${PORK_ADDRESS}",
    "${AMOUNT_TOKEN}",
    0,
    0,
    "${process.env.LIQUIDITY_WALLET}",
    Math.floor(Date.now() / 1000) + 3600,
    { value: "${AMOUNT_ETH}" }
  );
  console.log("Liquidity added:", tx.hash);
  await tx.wait();
}
main().catch(error => { console.error(error); process.exit(1); });
EOL

npx hardhat run scripts/temp_add_liquidity.js --network $NETWORK
rm scripts/temp_add_liquidity.js
