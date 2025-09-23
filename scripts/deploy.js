const hre = require("hardhat");
require("dotenv").config();
const fs = require("fs");

async function main() {
  const {
    TEAM_WALLET,
    PRESALE_WALLET,
    AIRDROP_WALLET,
    STAKING_WALLET,
    REWARDS_WALLET,
    LIQUIDITY_WALLET
  } = process.env;

  if (!TEAM_WALLET || !PRESALE_WALLET || !AIRDROP_WALLET || !STAKING_WALLET || !REWARDS_WALLET || !LIQUIDITY_WALLET) {
    throw new Error("⚠️ Missing allocation wallet env vars in .env");
  }

  const [deployer] = await hre.ethers.getSigners();
  const networkName = hre.network.name;
  console.log(`🌐 Deploying to ${networkName}`);
  console.log("🚀 Deploying with:", deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(await deployer.getBalance()));

  const Porkelon = await hre.ethers.getContractFactory("PorkelonPolygon");
  const porkelon = await Porkelon.deploy(
    TEAM_WALLET,
    PRESALE_WALLET,
    AIRDROP_WALLET,
    STAKING_WALLET,
    REWARDS_WALLET,
    LIQUIDITY_WALLET
  );

  await porkelon.waitForDeployment();
  const address = await porkelon.getAddress();
  console.log("✅ Deployed PorkelonPolygon at:", address);

  // Save address to file
  fs.writeFileSync("deployed-address.txt", address);
  console.log("📄 Saved address to deployed-address.txt");

  // Verify contract (skip on hardhat local network)
  if (networkName !== "hardhat" && process.env.POLYGONSCAN_API_KEY) {
    console.log("⏳ Verifying contract on Polygonscan...");
    await hre.run("verify:verify", {
      address,
      constructorArguments: [TEAM_WALLET, PRESALE_WALLET, AIRDROP_WALLET, STAKING_WALLET, REWARDS_WALLET, LIQUIDITY_WALLET],
    });
    console.log("✅ Contract verified!");
  }
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error("❌ Deployment failed:", err);
    process.exit(1);
  });
