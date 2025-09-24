const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("======================================");
  console.log("🚀 Deploying Upgradeable PorkelonPolygon Token to Polygon...");
  console.log("👤 Deployer Address:", deployer.address);
  console.log("💰 Balance:", ethers.formatEther(await deployer.getBalance()));
  console.log("======================================");

  // Load wallet addresses from .env
  const TEAM_WALLET = process.env.TEAM_WALLET;
  const LIQUIDITY_WALLET = process.env.LIQUIDITY_WALLET;

  if (!TEAM_WALLET || !LIQUIDITY_WALLET) {
    throw new Error("⚠️ Missing TEAM_WALLET or LIQUIDITY_WALLET in .env");
  }

  // Load contract factory
  const PorkelonPolygon = await ethers.getContractFactory("PorkelonPolygon");

  // Deploy as upgradeable proxy (UUPS)
  const porkelon = await upgrades.deployProxy(
    PorkelonPolygon,
    [TEAM_WALLET, LIQUIDITY_WALLET],
    { initializer: "initialize", kind: "uups" }
  );
  await porkelon.waitForDeployment();

  const proxyAddress = await porkelon.getAddress();
  console.log("✅ PorkelonPolygon Proxy deployed to:", proxyAddress);

  // Get implementation address
  const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("🛠️ Implementation address:", implAddress);

  // Optional: verify on PolygonScan
  if (process.env.POLYGONSCAN_API_KEY) {
    console.log("🔍 Verifying implementation contract...");
    try {
      await hre.run("verify:verify", {
        address: implAddress,
        constructorArguments: [],
      });
      console.log("✅ Verified implementation at:", implAddress);
    } catch (e) {
      console.warn("⚠️ Verification skipped:", e.message);
    }
  }

  console.log("🎉 Deployment complete. Proxy is ready for upgrades.");
}

main().catch((err) => {
  console.error("❌ Deployment failed:", err);
  process.exitCode = 1;
});
