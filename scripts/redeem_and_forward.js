const { ethers } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("Starting PorkelonPresale redemption and forwarding...");

  // Load deployer and network
  const [deployer] = await ethers.getSigners();
  const network = (await ethers.provider.getNetwork()).name;
  console.log(`Network: ${network}`);
  console.log(`Deployer account: ${deployer.address}`);
  console.log(`POL Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} POL`);

  // Configuration
  const PRESALE_ADDRESS = process.env.PORKELON_PRESALE_ADDRESS || "0xYOUR_PRESALE_ADDRESS";
  const FORWARD_ADDRESS = process.env.FORWARD_ADDRESS || process.env.DEV_WALLET || "0xBc2E051f3Dedcd0B9dDCA2078472f513a39df2C6";
  const PORKELON_PROXY_ADDRESS = process.env.PORKELON_PROXY_ADDRESS || "0xYOUR_PROXY_ADDRESS";
  const deploymentsPath = path.resolve(__dirname, "../deployments.json");

  // Off-chain validation
  if (!ethers.isAddress(PRESALE_ADDRESS) || PRESALE_ADDRESS === "0xYOUR_PRESALE_ADDRESS") {
    throw new Error("Invalid or unset PORKELON_PRESALE_ADDRESS. Set in .env or run show-address.js.");
  }
  if (!ethers.isAddress(FORWARD_ADDRESS)) {
    throw new Error(`Invalid FORWARD_ADDRESS or DEV_WALLET: ${FORWARD_ADDRESS}`);
  }
  if (!ethers.isAddress(PORKELON_PROXY_ADDRESS) || PORKELON_PROXY_ADDRESS === "0xYOUR_PROXY_ADDRESS") {
    throw new Error("Invalid or unset PORKELON_PROXY_ADDRESS. Set in .env or run show-address.js.");
  }

  // Load presale contract
  const presaleAbi = [
    "function owner() view returns (address)",
    "function endTime() view returns (uint256)",
    "function withdraw() external",
    "function withdrawTokens(address token, address to, uint256 amount) external",
    "function balanceOf(address account) view returns (uint256)"
  ];
  const presale = await ethers.getContractAt(presaleAbi, PRESALE_ADDRESS, deployer);

  // Verify presale contract exists
  const presaleCode = await ethers.provider.getCode(PRESALE_ADDRESS);
  if (presaleCode === "0x") {
    throw new Error(`No contract found at presale address: ${PRESALE_ADDRESS}`);
  }

  // Verify ownership
  const owner = await presale.owner();
  if (owner.toLowerCase() !== deployer.address.toLowerCase()) {
    throw new Error(`Deployer ${deployer.address} is not the owner of the presale contract (${owner})`);
  }

  // Check if presale has ended
  const endTime = await presale.endTime();
  const currentTime = Math.floor(Date.now() / 1000);
  if (currentTime < endTime) {
    console.warn(`Warning: Presale has not ended yet (ends at ${new Date(endTime * 1000).toISOString()}). Proceeding with redemption...`);
  }

  // Get Porkelon contract for token balance checks
  const porkelonAbi = [
    "function balanceOf(address account) view returns (uint256)",
    "function totalSupply() view returns (uint256)"
  ];
  const porkelon = await ethers.getContractAt(porkelonAbi, PORKELON_PROXY_ADDRESS, deployer);

  // Check presale contract's token balance
  const presaleTokenBalance = await porkelon.balanceOf(PRESALE_ADDRESS);
  console.log(`Presale contract token balance: ${ethers.formatEther(presaleTokenBalance)} PORK`);

  // Get gas parameters
  const feeData = await ethers.provider.getFeeData();
  const gasPrice = feeData.gasPrice || (await ethers.provider.getGasPrice());
  const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas || gasPrice;
  const maxFeePerGas = feeData.maxFeePerGas || gasPrice;
  console.log(`Gas price: ${ethers.formatUnits(maxFeePerGas, "gwei")} gwei`);
  console.log(`Priority fee: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} gwei`);

  // Estimate gas for withdrawing POL (native currency)
  console.log("Estimating gas for withdrawing POL...");
  let gasLimit;
  try {
    gasLimit = await presale.withdraw.estimateGas();
    console.log(`Estimated gas limit (POL withdrawal): ${gasLimit.toString()} gas units`);
    const estimatedCost = gasLimit * maxFeePerGas;
    console.log(`Estimated cost (POL withdrawal): ${ethers.formatEther(estimatedCost)} POL`);

    // Apply 15% gas limit buffer
    gasLimit = (gasLimit * BigInt(115)) / BigInt(100);
    console.log(`Buffered gas limit (POL withdrawal): ${gasLimit.toString()} gas units`);
    console.log(`Buffered cost (POL withdrawal): ${ethers.formatEther(gasLimit * maxFeePerGas)} POL`);

    // Check deployer balance
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    if (deployerBalance < estimatedCost) {
      throw new Error(
        `Insufficient POL balance: ${ethers.formatEther(deployerBalance)} POL available, ` +
        `${ethers.formatEther(estimatedCost)} POL required for POL withdrawal`
      );
    }
  } catch (e) {
    console.warn(`Warning: POL withdrawal estimation failed: ${e.message}. Skipping POL withdrawal.`);
    gasLimit = null;
  }

  // Withdraw POL if possible
  let polWithdrawn = false;
  if (gasLimit) {
    console.log(`Withdrawing POL to ${FORWARD_ADDRESS}...`);
    try {
      const tx = await presale.withdraw({ gasLimit, maxPriorityFeePerGas, maxFeePerGas });
      const receipt = await tx.wait();
      console.log(`POL withdrawn successfully!`);
      console.log(`Actual gas used (POL withdrawal): ${receipt.gasUsed.toString()} gas units`);
      console.log(`Actual cost (POL withdrawal): ${ethers.formatEther(receipt.gasUsed * maxFeePerGas)} POL`);
      polWithdrawn = true;
    } catch (e) {
      console.error(`Error withdrawing POL: ${e.message}`);
    }
  }

  // Estimate gas for withdrawing tokens
  console.log("Estimating gas for withdrawing tokens...");
  try {
    gasLimit = await presale.withdrawTokens.estimateGas(PORKELON_PROXY_ADDRESS, FORWARD_ADDRESS, presaleTokenBalance);
    console.log(`Estimated gas limit (token withdrawal): ${gasLimit.toString()} gas units`);
    const estimatedCost = gasLimit * maxFeePerGas;
    console.log(`Estimated cost (token withdrawal): ${ethers.formatEther(estimatedCost)} POL`);

    // Apply 15% gas limit buffer
    gasLimit = (gasLimit * BigInt(115)) / BigInt(100);
    console.log(`Buffered gas limit (token withdrawal): ${gasLimit.toString()} gas units`);
    console.log(`Buffered cost (token withdrawal): ${ethers.formatEther(gasLimit * maxFeePerGas)} POL`);

    // Check deployer balance
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    if (deployerBalance < estimatedCost) {
      throw new Error(
        `Insufficient POL balance: ${ethers.formatEther(deployerBalance)} POL available, ` +
        `${ethers.formatEther(estimatedCost)} POL required for token withdrawal`
      );
    }
  } catch (e) {
    throw new Error(`Gas estimation failed for token withdrawal: ${e.message}`);
  }

  // Withdraw tokens
  console.log(`Withdrawing ${ethers.formatEther(presaleTokenBalance)} PORK to ${FORWARD_ADDRESS}...`);
  const tx = await presale.withdrawTokens(PORKELON_PROXY_ADDRESS, FORWARD_ADDRESS, presaleTokenBalance, {
    gasLimit,
    maxPriorityFeePerGas,
    maxFeePerGas
  });
  const receipt = await tx.wait();
  console.log(`Tokens withdrawn successfully!`);
  console.log(`Actual gas used (token withdrawal): ${receipt.gasUsed.toString()} gas units`);
  console.log(`Actual cost (token withdrawal): ${ethers.formatEther(receipt.gasUsed * maxFeePerGas)} POL`);

  // Verify forwarded balances
  const forwardAddressTokenBalance = await porkelon.balanceOf(FORWARD_ADDRESS);
  console.log(`Forward address (${FORWARD_ADDRESS}) token balance: ${ethers.formatEther(forwardAddressTokenBalance)} PORK`);

  // Update deployments.json
  try {
    let deployments = {};
    try {
      deployments = JSON.parse(await fs.readFile(deploymentsPath, "utf8"));
    } catch (e) {
      console.warn("deployments.json not found, creating new one.");
    }
    deployments.redemptionTimestamp = new Date().toISOString();
    deployments.polWithdrawn = polWithdrawn;
    deployments.tokensWithdrawn = ethers.formatEther(presaleTokenBalance);
    deployments.forwardAddress = FORWARD_ADDRESS;
    await fs.writeFile(deploymentsPath, JSON.stringify(deployments, null, 2));
    console.log("Updated deployments.json with redemption details");
  } catch (e) {
    console.error(`Error updating deployments.json: ${e.message}`);
  }

  // Log verification note
  console.log(`\nNote: If contracts need verification, run show-address.js to get addresses and verification commands.`);
}

main()
  .then(() => {
    console.log("Redemption and forwarding completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error during redemption and forwarding:", error);
    process.exit(1);
  });
