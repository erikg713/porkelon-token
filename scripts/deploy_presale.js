const hre = require("hardhat");

async function main() {
  const DEV_WALLET = "0xBc2E051f3Dedcd0B9dDCA2078472f513a39df2C6";

  // --- configurable params ---
  const TOKEN = "0xYOUR_PORKELON_TOKEN_ADDRESS"; // PORK token
  const USDT = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"; // Polygon USDT (mainnet)
  const MATIC_RATE = 100000; // tokens per 1 MATIC
  const USDT_RATE = 100000;  // tokens per 1 USDT
  const CAP = hre.ethers.parseEther("500000000"); // 500M tokens
  const MIN_PURCHASE_MATIC = hre.ethers.parseEther("0.1");
  const MAX_PURCHASE_MATIC = hre.ethers.parseEther("5");
  const PER_WALLET_CAP = hre.ethers.parseEther("10000000");
  const LOCAL_OFFSET_HOURS = 0; // adjust if you want local time start
  const MATIC_USD_PRICE = 0.3 * 1e6; // USDT base units (6 decimals)

  const Presale = await hre.ethers.getContractFactory("Presale");
  const presale = await Presale.deploy(
    TOKEN,
    USDT,
    DEV_WALLET,
    MATIC_RATE,
    USDT_RATE,
    CAP,
    MIN_PURCHASE_MATIC,
    MAX_PURCHASE_MATIC,
    PER_WALLET_CAP,
    LOCAL_OFFSET_HOURS,
    MATIC_USD_PRICE
  );

  await presale.waitForDeployment();

  console.log(`✅ Presale deployed at: ${await presale.getAddress()}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

const { ethers, upgrades } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("Starting Porkelon upgrade and presale deployment...");

  // Load deployer
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("POL Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // Configuration
  const PROXY_ADDRESS = process.env.PORKELON_PROXY_ADDRESS || "0xYOUR_PROXY_ADDRESS";
  const DEV_WALLET = process.env.DEV_WALLET || "0xBc2E051f3Dedcd0B9dDCA2078472f513a39df2C6";
  const PRESALE_TOKEN_PRICE = process.env.PRESALE_TOKEN_PRICE || "1000000000000000"; // 1e15 wei/token
  const PRESALE_MIN_PURCHASE = process.env.PRESALE_MIN_PURCHASE || "100000000000000000"; // 0.1 POL
  const PRESALE_MAX_PURCHASE = process.env.PRESALE_MAX_PURCHASE || "10000000000000000000"; // 10 POL
  const PRESALE_START_TIME = process.env.PRESALE_START_TIME || Math.floor(Date.now() / 1000) + 3600; // Start in 1 hour
  const PRESALE_END_TIME = process.env.PRESALE_END_TIME || Math.floor(Date.now() / 1000) + 86400 * 7; // End in 7 days
  const PRESALE_TOTAL_TOKENS = process.env.PRESALE_TOTAL_TOKENS || "30000000000" + "0".repeat(18); // 30B tokens

  // Off-chain validation
  if (!ethers.isAddress(PROXY_ADDRESS) || PROXY_ADDRESS === "0xYOUR_PROXY_ADDRESS") {
    throw new Error("Invalid or unset PROXY_ADDRESS. Set PORKELON_PROXY_ADDRESS in .env.");
  }
  if (deployer.address.toLowerCase() !== DEV_WALLET.toLowerCase()) {
    throw new Error(`Deployer (${deployer.address}) must be DEV_WALLET (${DEV_WALLET})`);
  }
  if (isNaN(PRESALE_TOKEN_PRICE) || isNaN(PRESALE_MIN_PURCHASE) || isNaN(PRESALE_MAX_PURCHASE) ||
      isNaN(PRESALE_START_TIME) || isNaN(PRESALE_END_TIME) || isNaN(PRESALE_TOTAL_TOKENS)) {
    throw new Error("Invalid presale parameters in .env. Ensure all values are numbers.");
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

  // Get gas parameters
  const feeData = await ethers.provider.getFeeData();
  const gasPrice = feeData.gasPrice || (await ethers.provider.getGasPrice());
  const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas || gasPrice;
  const maxFeePerGas = feeData.maxFeePerGas || gasPrice;
  console.log(`Gas price: ${ethers.formatUnits(maxFeePerGas, "gwei")} gwei`);
  console.log(`Priority fee: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} gwei`);

  // Upgrade Porkelon proxy
  console.log("Estimating gas for Porkelon upgrade...");
  const Porkelon = await ethers.getContractFactory("Porkelon");
  const upgradeTx = await upgrades.upgradeProxy.populateTransaction(PROXY_ADDRESS, Porkelon, {
    kind: "uups",
    timeout: 600000,
    pollingInterval: 1000
  });

  let gasLimit;
  try {
    gasLimit = await ethers.provider.estimateGas({
      ...upgradeTx,
      maxPriorityFeePerGas,
      maxFeePerGas
    });
    console.log(`Estimated gas limit (upgrade): ${gasLimit.toString()} gas units`);
    const estimatedCost = gasLimit * maxFeePerGas;
    console.log(`Estimated cost (upgrade): ${ethers.formatEther(estimatedCost)} POL`);

    // Apply 15% gas limit buffer
    gasLimit = (gasLimit * BigInt(115)) / BigInt(100);
    console.log(`Buffered gas limit (upgrade): ${gasLimit.toString()} gas units`);
    console.log(`Buffered cost (upgrade): ${ethers.formatEther(gasLimit * maxFeePerGas)} POL`);

    // Check deployer balance
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    if (deployerBalance < estimatedCost) {
      throw new Error(
        `Insufficient POL balance: ${ethers.formatEther(deployerBalance)} POL available, ` +
        `${ethers.formatEther(estimatedCost)} POL required for upgrade`
      );
    }
  } catch (e) {
    throw new Error(`Gas estimation failed for upgrade: ${e.message}`);
  }

  console.log("Upgrading Porkelon at proxy:", PROXY_ADDRESS);
  const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, Porkelon, {
    kind: "uups",
    timeout: 600000,
    pollingInterval: 1000,
    gasLimit,
    maxPriorityFeePerGas,
    maxFeePerGas
  });
  const upgradeReceipt = await upgraded.waitForDeployment();
  console.log("Porkelon upgraded successfully");
  console.log(`Actual gas used (upgrade): ${upgradeReceipt.gasUsed.toString()} gas units`);
  console.log(`Actual cost (upgrade): ${ethers.formatEther(upgradeReceipt.gasUsed * maxFeePerGas)} POL`);

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

  // Deploy PorkelonPresale
  console.log("Estimating gas for PorkelonPresale deployment...");
  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presaleDeployTx = await PorkelonPresale.getDeployTransaction(
    PROXY_ADDRESS,
    BigInt(PRESALE_TOKEN_PRICE),
    BigInt(PRESALE_MIN_PURCHASE),
    BigInt(PRESALE_MAX_PURCHASE),
    BigInt(PRESALE_START_TIME),
    BigInt(PRESALE_END_TIME),
    BigInt(PRESALE_TOTAL_TOKENS)
  );

  try {
    gasLimit = await ethers.provider.estimateGas({
      ...presaleDeployTx,
      maxPriorityFeePerGas,
      maxFeePerGas
    });
    console.log(`Estimated gas limit (presale): ${gasLimit.toString()} gas units`);
    const estimatedCost = gasLimit * maxFeePerGas;
    console.log(`Estimated cost (presale): ${ethers.formatEther(estimatedCost)} POL`);

    // Apply 15% gas limit buffer
    gasLimit = (gasLimit * BigInt(115)) / BigInt(100);
    console.log(`Buffered gas limit (presale): ${gasLimit.toString()} gas units`);
    console.log(`Buffered cost (presale): ${ethers.formatEther(gasLimit * maxFeePerGas)} POL`);

    // Check deployer balance
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    if (deployerBalance < estimatedCost) {
      throw new Error(
        `Insufficient POL balance: ${ethers.formatEther(deployerBalance)} POL available, ` +
        `${ethers.formatEther(estimatedCost)} POL required for presale deployment`
      );
    }
  } catch (e) {
    throw new Error(`Gas estimation failed for presale deployment: ${e.message}`);
  }

  console.log("Deploying PorkelonPresale...");
  const presale = await PorkelonPresale.deploy(
    PROXY_ADDRESS,
    BigInt(PRESALE_TOKEN_PRICE),
    BigInt(PRESALE_MIN_PURCHASE),
    BigInt(PRESALE_MAX_PURCHASE),
    BigInt(PRESALE_START_TIME),
    BigInt(PRESALE_END_TIME),
    BigInt(PRESALE_TOTAL_TOKENS),
    { gasLimit, maxPriorityFeePerGas, maxFeePerGas }
  );
  const presaleReceipt = await presale.waitForDeployment();
  const presaleAddress = await presale.getAddress();
  console.log("PorkelonPresale deployed to:", presaleAddress);
  console.log(`Actual gas used (presale): ${presaleReceipt.gasUsed.toString()} gas units`);
  console.log(`Actual cost (presale): ${ethers.formatEther(presaleReceipt.gasUsed * maxFeePerGas)} POL`);

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
  deployments.PorkelonPresale = presaleAddress;
  deployments.upgradeTimestamp = new Date().toISOString();
  deployments.presaleDeployTimestamp = new Date().toISOString();
  await fs.writeFile(deploymentsPath, JSON.stringify(deployments, null, 2));
  console.log("Updated deployments.json");

  // Log verification commands
  const network = (await ethers.provider.getNetwork()).name;
  console.log(`Verify Porkelon on PolygonScan (network: ${network}):`);
  console.log(`npx hardhat verify --network ${network} ${implementationAddress}`);
  console.log(`Verify PorkelonPresale on PolygonScan (network: ${network}):`);
  console.log(`npx hardhat verify --network ${network} ${presaleAddress} "${PROXY_ADDRESS}" "${PRESALE_TOKEN_PRICE}" "${PRESALE_MIN_PURCHASE}" "${PRESALE_MAX_PURCHASE}" "${PRESALE_START_TIME}" "${PRESALE_END_TIME}" "${PRESALE_TOTAL_TOKENS}"`);
}

main()
  .then(() => {
    console.log("Upgrade and presale deployment completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error during upgrade or presale deployment:", error);
    process.exit(1);
  });
