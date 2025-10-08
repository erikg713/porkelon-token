const { ethers, upgrades } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

const config = {
  proxyAddress: process.env.PORKELON_PROXY_ADDRESS || "0xYOUR_PROXY_ADDRESS",
  devWallet: process.env.DEV_WALLET || "0xBc2E051f3Dedcd0B9dDCA2078472f513a39df2C6",
  presale: {
    tokenPrice: BigInt(process.env.PRESALE_TOKEN_PRICE || "1000000000000000"), // 1e15 wei/token
    minPurchase: BigInt(process.env.PRESALE_MIN_PURCHASE || "100000000000000000"), // 0.1 POL
    maxPurchase: BigInt(process.env.PRESALE_MAX_PURCHASE || "10000000000000000000"), // 10 POL
    startTime: BigInt(process.env.PRESALE_START_TIME || Math.floor(Date.now() / 1000) + 3600), // Start in 1 hour
    endTime: BigInt(process.env.PRESALE_END_TIME || Math.floor(Date.now() / 1000) + 86400 * 7), // End in 7 days
    totalTokens: BigInt(process.env.PRESALE_TOTAL_TOKENS || "30000000000" + "0".repeat(18)), // 30B tokens
  },
  gasBuffer: 1.15, // 15% buffer for gas estimation
};

async function validateEnvironment(deployer) {
  if (!ethers.isAddress(config.proxyAddress) || config.proxyAddress === "0xYOUR_PROXY_ADDRESS") {
    throw new Error("Invalid or unset PROXY_ADDRESS. Set PORKELON_PROXY_ADDRESS in .env.");
  }
  if (deployer.address.toLowerCase() !== config.devWallet.toLowerCase()) {
    throw new Error(`Deployer (${deployer.address}) must be DEV_WALLET (${config.devWallet})`);
  }
}

async function estimateGas(transaction, gasParams) {
  try {
    const gasLimit = await ethers.provider.estimateGas({ ...transaction, ...gasParams });
    const bufferedGasLimit = BigInt(Math.ceil(Number(gasLimit) * config.gasBuffer));
    return { gasLimit: bufferedGasLimit, estimatedCost: bufferedGasLimit * gasParams.maxFeePerGas };
  } catch (error) {
    throw new Error(`Gas estimation failed: ${error.message}`);
  }
}

async function deployPresale(deployer, gasParams) {
  console.log("Deploying PorkelonPresale...");

  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presale = await PorkelonPresale.deploy(
    config.proxyAddress,
    config.presale.tokenPrice,
    config.presale.minPurchase,
    config.presale.maxPurchase,
    config.presale.startTime,
    config.presale.endTime,
    config.presale.totalTokens,
    gasParams
  );

  const receipt = await presale.waitForDeployment();
  console.log(`PorkelonPresale deployed to: ${await presale.getAddress()}`);
  console.log(`Gas used: ${receipt.gasUsed.toString()} units`);
  return presale;
}

async function main() {
  console.log("Starting presale deployment...");

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying with account: ${deployer.address}`);
  console.log(`POL Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))}`);

  await validateEnvironment(deployer);

  const feeData = await ethers.provider.getFeeData();
  const gasParams = {
    maxPriorityFeePerGas: feeData.maxPriorityFeePerGas || feeData.gasPrice,
    maxFeePerGas: feeData.maxFeePerGas || feeData.gasPrice,
  };

  const presale = await deployPresale(deployer, gasParams);

  // Save deployment details
  const deploymentsPath = path.resolve(__dirname, "../deployments.json");
  const deployments = {
    PorkelonPresale: await presale.getAddress(),
    deployTimestamp: new Date().toISOString(),
  };
  await fs.writeFile(deploymentsPath, JSON.stringify(deployments, null, 2));
  console.log("Deployment details saved to deployments.json");
}

main()
  .then(() => console.log("Presale deployment completed successfully!"))
  .catch((error) => {
    console.error("Error during deployment:", error);
    process.exit(1);
  });
