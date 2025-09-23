const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const { TEAM_WALLET } = process.env; // Unused here, but for reference
  const TOKEN_ADDRESS = "YOUR_DEPLOYED_PORKELON_ADDRESS"; // Fill after deploy
  const QUICKSWAP_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57f7D7A678ff";
  const MATIC_AMOUNT = ethers.parseEther("100"); // Example: 100 MATIC for liquidity; adjust
  const TOKEN_AMOUNT = ethers.parseUnits("40000000000", 18); // 40B PORK; adjust if partial

  const porkelon = await ethers.getContractAt("IERC20", TOKEN_ADDRESS);
  const router = await ethers.getContractAt("IUniswapV2Router02", QUICKSWAP_ROUTER);

  // Approve token to router
  await porkelon.approve(QUICKSWAP_ROUTER, TOKEN_AMOUNT);
  console.log("Approved tokens for liquidity");

  // Add liquidity (deadline: 20 min from now)
  await router.addLiquidityETH(
    TOKEN_ADDRESS,
    TOKEN_AMOUNT,
    0, // Min token
    0, // Min ETH
    await ethers.provider.getSigner().getAddress(), // LP to signer (liquidity_wallet)
    Math.floor(Date.now() / 1000) + 60 * 20,
    { value: MATIC_AMOUNT }
  );
  console.log("Liquidity added");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
