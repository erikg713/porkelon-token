const { ethers, upgrades } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("Starting Porkelon upgrade...");

  // Load deployer
  const [deployer] = await ethers.getSigners();
  console.log("Upgrading with account:", deployer.address);

  // Configuration
  const PROXY_ADDRESS = process.env.PORKELON_PROXY_ADDRESS || "0xYOUR_PROXY_ADDRESS";
  const DEV_WALLET = process.env.DEV_WALLET || "0xBc2E051f3Dedcd0B9dDCA2078472f513a39df2C6";

  // Off-chain validation
  if (!ethers.isAddress(PROXY_ADDRESS) || PROXY_ADDRESS === "0xYOUR_PROXY_ADDRESS") {
    throw new Error("Invalid or unset PROXY_ADDRESS. Set PORKELON_PROXY_ADDRESS in .env.");
  }
  if (deployer.address.toLowerCase() !== DEV_WALLET.toLowerCase()) {
    throw new Error(`Deployer (${deployer.address}) must be DEV_WALLET (${DEV_WALLET})`);
  }

  // Minimal ABI for proxy contract
  const porkelonAbi = [
    "function hasRole(bytes32 role, address account) view returns (bool)",
    "function UPGRADER_ROLE() view returns (bytes32)",
    "function teamWallet() view returns (address)",
    "function balanceOf(address account) view returns (uint256)",
    "function totalSupply() view returns (uint256)"
  ];
  const porkelon = await ethers.getContractAt(porkelonAbi, PROXY_ADDRESS, deployer);

  // Verify UPGRADER_ROLE
  const UPGRADER_ROLE = await porkelon.UPGRADER_ROLE();
  if (!(await porkelon.hasRole(UPGRADER_ROLE, deployer.address))) {
    throw new Error(`Deployer ${deployer.address} does not have UPGRADER_ROLE`);
  }

  // Verify proxy exists
  const proxyCode = await ethers.provider.getCode(PROXY_ADDRESS);
  if (proxyCode === "0x") {
    throw new Error(`No contract found at proxy address: ${PROXY_ADDRESS}`);
  }

  // Get team wallet and pre-upgrade balances
  const teamWallet = await porkelon.teamWallet();
  const teamBalance = await porkelon.balanceOf(teamWallet);
  const totalSupply = await porkelon.totalSupply();
  console.log(`Team wallet: ${teamWallet}`);
  console.log(`Team balance: ${ethers.formatEther(teamBalance)} PORK`);
  console.log(`Total supply: ${ethers.formatEther(totalSupply)} PORK`);

  // Get contract factory
  const Porkelon = await ethers.getContractFactory("Porkelon");

  // Estimate gas with EIP-1559 parameters
  console.log("Estimating gas for upgrade...");
  const feeData = await ethers.provider.getFeeData();
  const gasPrice = feeData.gasPrice || (await ethers.provider.getGasPrice());
  const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas || gasPrice;
  const maxFeePerGas = feeData.maxFeePerGas || gasPrice;
  console.log(`Gas price: ${ethers.formatUnits(maxFeePerGas, "gwei")} gwei`);
  console.log(`Priority fee: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} gwei`);

  // Prepare upgrade transaction
  const upgradeTx = await upgrades.upgradeProxy.populateTransaction(PROXY_ADDRESS, Porkelon, {
    kind: "uups",
    timeout: 600000,
    pollingInterval: 1000
  });

  // Estimate gas limit
  let gasLimit;
  try {
    gasLimit = await ethers.provider.estimateGas({
      ...upgradeTx,
      maxPriorityFeePerGas,
      maxFeePerGas
    });
    console.log(`Estimated gas limit: ${gasLimit.toString()} gas units`);

    // Calculate cost
    const estimatedCost = gasLimit * maxFeePerGas;
    console.log(`Estimated cost: ${ethers.formatEther(estimatedCost)} POL`);

    // Apply 15% gas limit buffer
    gasLimit = (gasLimit * BigInt(115)) / BigInt(100);
    console.log(`Gas limit with 15% buffer: ${gasLimit.toString()} gas units`);
    console.log(`Buffered cost: ${ethers.formatEther(gasLimit * maxFeePerGas)} POL`);

    // Check deployer balance
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    if (deployerBalance < estimatedCost) {
      throw new Error(
        `Insufficient POL balance: ${ethers.formatEther(deployerBalance)} POL available, ` +
        `${ethers.formatEther(estimatedCost)} POL required`
      );
    }
  } catch (e) {
    throw new Error(`Gas estimation failed: ${e.message}`);
  }

  // Upgrade the proxy
  console.log("Upgrading Porkelon at proxy:", PROXY_ADDRESS);
  const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, Porkelon, {
    kind: "uups",
    timeout: 600000,
    pollingInterval: 1000,
    gasLimit,
    maxPriorityFeePerGas,
    maxFeePerGas
  });
  const txReceipt = await upgraded.waitForDeployment();
  console.log("Porkelon upgraded successfully");
  console.log(`Actual gas used: ${txReceipt.gasUsed.toString()} gas units`);
  console.log(`Actual cost: ${ethers.formatEther(txReceipt.gasUsed * maxFeePerGas)} POL`);

  // Log implementation address
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(PROXY_ADDRESS);
  console.log("New implementation address:", implementationAddress);

  // Test version() if available
  try {
    console.log("Contract version:", await upgraded.version());
  } catch (e) {
    console.warn("Warning: version() not available:", e.message);
  }

  // Verify post-upgrade balances
  const newTeamBalance = await porkelon.balanceOf(teamWallet);
  const newTotalSupply = await porkelon.totalSupply();
  console.log(`Team balance post-upgrade: ${ethers.formatEther(newTeamBalance)} PORK`);
  console.log(`Total supply post-upgrade: ${ethers.formatEther(newTotalSupply)} PORK`);
  if (!newTeamBalance.eq(teamBalance)) {
    console.warn("Warning: Team wallet balance changed during upgrade!");
  }
  if (!newTotalSupply.eq(totalSupply)) {
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
  console.log("Updated deployments.json");

  // Log verification command
  const network = (await ethers.provider.getNetwork()).name;
  console.log(`Verify on PolygonScan (network: ${network}):`);
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
