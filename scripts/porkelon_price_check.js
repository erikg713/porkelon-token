import { ethers } from "ethers";

// === CONFIGURATION ===
const RPC_URL = "https://polygon-rpc.com";
const ROUTER_V2 = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff"; // QuickSwap Router
const PORK = "0xba4284495ce3b8c029c2cbabc821526464a93ca9"; // Porkelon Token
const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";  // USDC (Polygon)

// === SETUP ===
const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const router = new ethers.Contract(
  ROUTER_V2,
  [
    "function getAmountsOut(uint256,address[]) view returns (uint256[])",
    "function getAmountsIn(uint256,address[]) view returns (uint256[])"
  ],
  provider
);

async function main() {
  console.log("🔍 Checking Porkelon ↔ USDC live rates on QuickSwap...");

  // 1. PORK → USDC
  const onePork = ethers.utils.parseUnits("1", 18);
  const path1 = [PORK, USDC];

  try {
    const out1 = await router.getAmountsOut(onePork, path1);
    const porkToUSDC = Number(ethers.utils.formatUnits(out1[1], 6));
    console.log(`💰 1 PORK = ${porkToUSDC} USDC`);
  } catch (e) {
    console.log("⚠️ No direct liquidity for PORK/USDC or route unavailable.");
  }

  // 2. USDC → PORK
  const oneUSDC = ethers.utils.parseUnits("1", 6);
  const path2 = [USDC, PORK];

  try {
    const out2 = await router.getAmountsOut(oneUSDC, path2);
    const usdcToPORK = Number(ethers.utils.formatUnits(out2[1], 18));
    console.log(`💵 1 USDC = ${usdcToPORK.toLocaleString()} PORK`);
  } catch (e) {
    console.log("⚠️ No reverse liquidity or path found for USDC → PORK.");
  }

  console.log("✅ Price check complete.");
}

main().catch(console.error);
