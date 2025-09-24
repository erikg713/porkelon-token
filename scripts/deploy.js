const { ethers, upgrades } = require("hardhat");

async function main() {
  const Porkelon = await ethers.getContractFactory("Porkelon");
  const porkelon = await upgrades.deployProxy(Porkelon, ["0xYourTeamWalletHere"], { initializer: 'initialize', kind: 'uups' });
  console.log("Porkelon deployed to:", await porkelon.getAddress());
}

main();

const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("======================================");
  console.log("🚀 Deploying Porkelon Upgradeable Token to Polygon...");
  console.log("👤 Deployer Address:", deployer.address);
  console.log("💰 Balance:", (await deployer.getBalance()).toString());
  console.log("======================================");

  // Load contract
  const Porkelon = await ethers.getContractFactory("Porkelon");

  // Initial supply (100B tokens with 18 decimals)
  const totalSupply = ethers.utils.parseUnits(
    process.env.TOTAL_SUPPLY || "100000000000",
    18
  );

  // Deploy as upgradeable proxy (UUPS)
  const porkelon = await upgrades.deployProxy(
    Porkelon,
    [totalSupply],
    { kind: "uups" }
  );
  await porkelon.waitForDeployment();

  console.log("✅ Porkelon Proxy deployed to:", await porkelon.getAddress());

  // Optional: verify on PolygonScan
  if (process.env.POLYGONSCAN_API_KEY) {
    console.log("🔍 Verifying implementation contract...");
    const impl = await upgrades.erc1967.getImplementationAddress(await porkelon.getAddress());
    try {
      await hre.run("verify:verify", {
        address: impl,
        constructorArguments: [],
      });
      console.log("✅ Verified implementation at:", impl);
    } catch (e) {
      console.warn("⚠️ Verification skipped:", e.message);
    }
  }

  console.log("🎉 Deployment complete.");
}

main().catch((err) => {
  console.error("❌ Deployment failed:", err);
  process.exitCode = 1;
});
