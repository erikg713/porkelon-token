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

  // Load presale contract with assumed ABI
  // TODO: Replace with actual PorkelonPresale ABI from artifacts/contracts/PorkelonPresale.sol/PorkelonPresale.json
  const presaleAbi = [
    "function owner() view returns (address)",
    "function endTime() view returns (uint256)",
    "function tokenPrice() view returns (uint256)",
    "function minPurchase() view returns (uint256)",
    "function maxPurchase() view returns (uint256)",
    "function startTime() view returns (uint256)",
    "function totalTokens() view returns (uint256)",
    "function token() view returns (address)",
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
  let owner;
  try {
    owner = await presale.owner();
    if (owner.toLowerCase() !== deployer.address.toLowerCase()) {
      throw new Error(`Deployer ${deployer.address} is not the owner of the presale contract (${owner})`);
    }
  } catch (e) {
    throw new Error(`Failed to verify presale ownership: ${e.message}. Check if 'owner()' exists in the contract ABI.`);
  }

  // Verify presale parameters
  let tokenAddress, tokenPrice, minPurchase, maxPurchase, startTime, endTime, totalTokens;
  try {
    tokenAddress = await presale.token();
    tokenPrice = await presale.tokenPrice();
    minPurchase = await presale.minPurchase();
    maxPurchase = await presale.maxPurchase();
    startTime = await presale.startTime();
    endTime = await presale.endTime();
    totalTokens = await presale.totalTokens();
    console.log("\nPresale contract parameters:");
    console.log(`Token Address: ${tokenAddress}`);
    console.log(`Token Price: ${ethers.formatUnits(tokenPrice, "wei")} wei/token`);
    console.log(`Min Purchase: ${ethers.formatEther(minPurchase)} POL`);
    console.log(`Max Purchase: ${ethers.formatEther(maxPurchase)} POL`);
    console.log(`Start Time: ${new Date(Number(startTime) * 1000).toISOString()}`);
    console.log(`End Time: ${new Date(Number(endTime) * 1000).toISOString()}`);
    console.log(`Total Tokens: ${ethers.formatEther(totalTokens)} PORK`);
  } catch (e) {
    console.warn(`Warning: Failed to fetch presale parameters: ${e.message}. Proceeding with redemption...`);
  }

  // Validate token address
  if (tokenAddress && tokenAddress.toLowerCase() !== PORKELON_PROXY_ADDRESS.toLowerCase()) {
    console.warn(`Warning: Presale token address (${tokenAddress}) does not match PORKELON_PROXY_ADDRESS (${PORKELON_PROXY_ADDRESS})`);
  }

  // Check if presale has ended
  if (endTime) {
    const currentTime = Math.floor(Date.now() / 1000);
    if (currentTime < endTime) {
      // TODO: If contract enforces endTime, uncomment the following to halt execution:
      // throw new Error(`Presale has not ended yet. Wait until ${new Date(Number(endTime) * 1000).toISOString()}`);
      console.warn(`Warning: Presale has not ended yet (ends at ${new Date(Number(endTime) * 1000).toISOString()}). Proceeding with redemption...`);
    }
  }

  // Get Porkelon contract for token balance checks
  const porkelonAbi = [
    "function balanceOf(address account) view returns (uint256)",
    "function totalSupply() view returns (uint256)"
  ];
  const porkelon = await ethers.getContractAt(porkelonAbi, PORKELON_PROXY_ADDRESS, deployer);

  // Check presale contract's token balance
  let presaleTokenBalance;
  try {
    presaleTokenBalance = await porkelon.balanceOf(PRESALE_ADDRESS);
    console.log(`Presale contract token balance: ${ethers.formatEther(presaleTokenBalance)} PORK`);
  } catch (e) {
    throw new Error(`Failed to fetch presale token balance: ${e.message}`);
  }

  // Get gas parameters
  const feeData = await ethers.provider.getFeeData();
  const gasPrice = feeData.gasPrice || (await ethers.provider.getGasPrice());
  const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas || gasPrice;
  const maxFeePerGas = feeData.maxFeePerGas || gasPrice;
  console.log(`Gas price: ${ethers.formatUnits(maxFeePerGas, "gwei")} gwei`);
  console.log(`Priority fee: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} gwei`);

  // Estimate gas for withdrawing POL
  console.log("Estimating gas for withdrawing POL...");
  let gasLimit;
  let polWithdrawn = false;
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

    // Withdraw POL
    console.log(`Withdrawing POL to ${FORWARD_ADDRESS}...`);
    const tx = await presale.withdraw({ gasLimit, maxPriorityFeePerGas, maxFeePerGas });
    const receipt = await tx.wait();
    console.log(`POL withdrawn successfully!`);
    console.log(`Actual gas used (POL withdrawal): ${receipt.gasUsed.toString()} gas units`);
    console.log(`Actual cost (POL withdrawal): ${ethers.formatEther(receipt.gasUsed * maxFeePerGas)} POL`);
    polWithdrawn = true;
  } catch (e) {
    console.warn(`Warning: POL withdrawal failed: ${e.message}. Skipping POL withdrawal.`);
    // TODO: If the contract uses a different function (e.g., redeemFunds()), update the call here.
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
    throw new Error(`Gas estimation failed for token withdrawal: ${e.message}. Check if 'withdrawTokens(address,address,uint256)' exists in the ABI.`);
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
