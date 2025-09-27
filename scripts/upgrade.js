const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "YOUR_DEPLOYED_PROXY_ADDRESS"; // replace after deploy

  console.log("Upgrading Porkelon at proxy:", proxyAddress);

  const PorkelonV2 = await ethers.getContractFactory("PorkelonV2");
  const upgraded = await upgrades.upgradeProxy(proxyAddress, PorkelonV2);

  console.log("Porkelon has been upgraded!");
  console.log("New contract at proxy:", await upgraded.getAddress());

  // Test: call version()
  console.log("Contract version:", await upgraded.version());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxy = process.env.PROXY_ADDRESS;
  if (!proxy) throw new Error("Set PROXY_ADDRESS in .env");

  const PorkelonV2 = await ethers.getContractFactory("PorkelonV2");
  const upgraded = await upgrades.upgradeProxy(proxy, PorkelonV2);

  console.log("Upgraded proxy at:", upgraded.address);
  console.log(
    "New implementation:",
    await upgrades.erc1967.getImplementationAddress(upgraded.address)
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


const { ethers, upgrades } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("Starting Porkelon upgrade...");

  // Load deployer
  const [deployer] = await ethers.getSigners();
  console.log("Upgrading with account:", deployer.address);
  console.log("POL Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // Configuration
  const PROXY_ADDRESS = process.env.PORKELON_PROXY_ADDRESS || "0xYOUR_PROXY_ADDRESS";
  const DEV_WALLET = process.env.DEV_WALLET || "0xBc2E051f3Dedcd0B9dDCA2078472f513a39df2C6";

  // Validate inputs
  if (!ethers.isAddress(PROXY_ADDRESS) || PROXY_ADDRESS === "0xYOUR_PROXY_ADDRESS") {
    throw new Error("Invalid or unset PROXY_ADDRESS. Set PORKELON_PROXY_ADDRESS in .env.");
  }
  if (deployer.address.toLowerCase() !== DEV_WALLET.toLowerCase()) {
    throw new Error(`Deployer (${deployer.address}) must be DEV_WALLET (${DEV_WALLET})`);
  }

  // Load existing proxy contract to verify UPGRADER_ROLE and team wallet
  const porkelonAbi = [
    "function hasRole(bytes32 role, address account) view returns (bool)",
    "function UPGRADER_ROLE() view returns (bytes32)",
    "function balanceOf(address account) view returns (uint256)",
    "function teamWallet() view returns (address)",
    "function totalSupply() view returns (uint256)"
  ];
  const porkelon = await ethers.getContractAt(porkelonAbi, PROXY_ADDRESS, deployer);
  const UPGRADER_ROLE = await porkelon.UPGRADER_ROLE();
  const hasUpgraderRole = await porkelon.hasRole(UPGRADER_ROLE, deployer.address);
  if (!hasUpgraderRole) {
    throw new Error(`Deployer ${deployer.address} does not have UPGRADER_ROLE`);
  }

  // Verify proxy exists and check team wallet balance
  const proxyCode = await ethers.provider.getCode(PROXY_ADDRESS);
  if (proxyCode === "0x") {
    throw new Error(`No contract found at proxy address: ${PROXY_ADDRESS}`);
  }
  const teamWallet = await porkelon.teamWallet();
  const teamBalance = await porkelon.balanceOf(teamWallet);
  const totalSupply = await porkelon.totalSupply();
  console.log(`Team wallet ${teamWallet} balance: ${ethers.formatEther(teamBalance)} PORK`);
  console.log(`Total supply: ${ethers.formatEther(totalSupply)} PORK`);

  // Get the new implementation contract factory
  const Porkelon = await ethers.getContractFactory("Porkelon");

  // Upgrade the proxy
  console.log("Upgrading Porkelon at proxy:", PROXY_ADDRESS);
  const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, Porkelon, {
    kind: "uups",
    timeout: 600000, // 10-minute timeout
    pollingInterval: 1000
  });
  await upgraded.waitForDeployment();
  console.log("Porkelon upgraded successfully");

  // Log implementation address
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(PROXY_ADDRESS);
  console.log("New implementation address:", implementationAddress);

  // Verify team wallet balance and total supply post-upgrade
  const newTeamBalance = await porkelon.balanceOf(teamWallet);
  const newTotalSupply = await porkelon.totalSupply();
  console.log(`Team wallet ${teamWallet} balance post-upgrade: ${ethers.formatEther(newTeamBalance)} PORK`);
  console.log(`Total supply post-upgrade: ${ethers.formatEther(newTotalSupply)} PORK`);
  if (newTeamBalance !== teamBalance) {
    console.warn("Warning: Team wallet balance changed during upgrade!");
  }
  if (newTotalSupply !== totalSupply) {
    console.warn("Warning: Total supply changed during upgrade!");
  }

  // Update deployments.json
  const deploymentsPath = path.resolve(__dirname, "../deployments.json");
  let deployments = {};
  try {
    deployments = JSON.parse(await fs.readFile(deploymentsPath, "utf8"));
  } catch (e) {
    console.warn("deployments.json not found, creating new one.");
  }
  deployments.PorkelonImplementation = implementationAddress;
  deployments.PorkelonProxy = PROXY_ADDRESS;
  deployments.upgradeTimestamp = new Date().toISOString();
  await fs.writeFile(deploymentsPath, JSON.stringify(deployments, null, 2));
  console.log("Updated deployments.json with new implementation address");

  // Log verification command
  const network = (await ethers.provider.getNetwork()).name;
  console.log(`Run the following to verify on PolygonScan (network: ${network}):`);
  console.log(`npx hardhat verify --network ${network} ${implementationAddress}`);
}

main()
  .then(() => {
    console.log("Upgrade completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error during upgrade:", error);
    process.exit(1);
  });
