// scripts/add_liquidity.js
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Adding liquidity with account:", deployer.address);

  // Replace with your deployed token address
  const TOKEN_ADDRESS = "0xYourDeployedPorkelonPolygonAddressHere";
  // QuickSwap Router on Polygon (Uniswap V2 compatible)
  const ROUTER_ADDRESS = "0xa5E0829CaCEd8fFDD4De3c53AFCB7e3c8bbb9742";  // QuickSwap V2 Router
  // USDT on Polygon (for token/USDT pair; use address(0) for MATIC)
  const PAIRED_TOKEN = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";  // USDT; or "0x0000000000000000000000000000000000000000" for MATIC
  const IS_MATIC_PAIR = PAIRED_TOKEN === "0x0000000000000000000000000000000000000000";

  // Amounts: Adjust based on your liquidity allocation (e.g., 40% of total supply)
  const TOKEN_AMOUNT = ethers.parseUnits("40000000000", 18);  // 40B tokens (40% of 100B)
  const PAIRED_AMOUNT = ethers.parseUnits("1000", 6);  // e.g., 1000 USDT (6 decimals); or for MATIC: ethers.parseEther("100") for 100 MATIC

  // Get contracts
  const token = await ethers.getContractAt("PorkelonPolygon", TOKEN_ADDRESS);
  const router = await
