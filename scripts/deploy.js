// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");

async function main() {
  console.log("Starting Porkelon ecosystem deployment...");
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("POL Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  const config = {
    teamWallet: process.env.TEAM_WALLET || "0xYourTeamWalletHere",
    presaleWallet: process.env.PRESALE_WALLET || "0xYourPresaleWalletHere",
    airdropWallet: process.env.AIRDROP_WALLET || "0xYourAirdropWalletHere",
    stakingWallet: process.env.STAKING_WALLET || "0xYourStakingWalletHere",
    marketingWallet: process.env.MARKETING_WALLET || "0xYourMarketingWalletHere",
    liquidityWallet: process.env.LIQUIDITY_WALLET || "0xYourLiquidityWalletHere",
    fundsWallet: process.env.FUNDS_WALLET || deployer.address,
    usdtAddress: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
    tokenPriceMatic: ethers.parseEther("0.000001"), // 1M PORK/MATIC
    tokenPriceUsdt: ethers.parseEther("0.001"), // 1K PORK/USDT
    minPurchase: ethers.parseEther("0.1"),
    maxPurchase: ethers.parseEther("10"),
    presaleCap: ethers.parseEther("10000000000"), // 10B PORK
    airdropPool: ethers.parseEther("5000000000"), // 5B PORK
    stakingPool: ethers.parseEther("10000000000"), // 10B PORK
    liquidityLock: ethers.parseEther("40000000000"), // 40B PORK
    marketingVault: ethers.parseEther("10000000000"), // 10B PORK
    lockDuration: 365 * 24 * 60 * 60, // 1 year
    vestingDuration: 2 * 365 * 24 * 60 * 60 // 2 years
  };

  for (const [key, value] of Object.entries(config)) {
    if (key.includes("Wallet") && !ethers.isAddress(value)) {
      throw new Error(`Invalid address for ${key}: ${value}`);
    }
  }

  // Deploy Porkelon
  console.log("Deploying Porkelon...");
  const Porkelon = await ethers.getContractFactory("Porkelon");
  const porkelon = await upgrades.deployProxy(
    Porkelon,
    [
      config.teamWallet,
      config.presaleWallet,
      config.airdropWallet,
      config.stakingWallet,
      config.marketingWallet,
      config.liquidityWallet
    ],
    { initializer: "initialize", kind: "uups" }
  );
  await porkelon.waitForDeployment();
  const tokenAddress = await porkelon.getAddress();
  console.log("Porkelon deployed to:", tokenAddress);

  // Deploy PorkelonPresale
  console.log("Deploying PorkelonPresale...");
  const startTime = Math.floor(Date.now() / 1000) + 3600;
  const endTime = startTime + 7 * 24 * 60 * 60;
  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presale = await PorkelonPresale.deploy(
    tokenAddress,
    config.usdtAddress,
    config.tokenPriceMatic,
    config.tokenPriceUsdt,
    config.minPurchase,
    config.maxPurchase,
    startTime,
    endTime,
    config.presaleCap
  );
  await presale.waitForDeployment();
  const presaleAddress = await presale.getAddress();
  console.log("PorkelonPresale deployed to:", presaleAddress);

  // Deploy PorkelonAirdrop
  console.log("Deploying PorkelonAirdrop...");
  const PorkelonAirdrop = await ethers.getContractFactory("PorkelonAirdrop");
  const airdrop = await PorkelonAirdrop.deploy(tokenAddress, config.airdropPool);
  await airdrop.waitForDeployment();
  const airdropAddress = await airdrop.getAddress();
  console.log("PorkelonAirdrop deployed to:", airdropAddress);

  // Deploy PorkelonStakingRewards
  console.log("Deploying PorkelonStakingRewards...");
  const PorkelonStakingRewards = await ethers.getContractFactory("PorkelonStakingRewards");
  const staking = await PorkelonStakingRewards.deploy(tokenAddress, tokenAddress, config.stakingPool);
  await staking.waitForDeployment();
  const stakingAddress = await staking.getAddress();
  console.log("PorkelonStakingRewards deployed to:", stakingAddress);

  // Deploy PorkelonLiquidityLocker
  console.log("Deploying PorkelonLiquidityLocker...");
  const PorkelonLiquidityLocker = await ethers.getContractFactory("PorkelonLiquidityLocker");
  const locker = await PorkelonLiquidityLocker.deploy(tokenAddress, config.liquidityWallet, config.liquidityLock);
  await locker.waitForDeployment();
  const liquidityLockerAddress = await locker.getAddress();
  console.log("PorkelonLiquidityLocker deployed to:", liquidityLockerAddress);

  // Deploy PorkelonMarketingVault
  console.log("Deploying PorkelonMarketingVault...");
  const PorkelonMarketingVault = await ethers.getContractFactory("PorkelonMarketingVault");
  const vault = await PorkelonMarketingVault.deploy(tokenAddress, config.marketingWallet, config.vestingDuration);
  await vault.waitForDeployment();
  const vaultAddress = await vault.getAddress();
  console.log("PorkelonMarketingVault deployed to:", vaultAddress);

  // Save deployment artifacts
  const artifacts = {
    Porkelon: tokenAddress,
    PorkelonPresale: presaleAddress,
    PorkelonAirdrop: airdropAddress,
    PorkelonStakingRewards: stakingAddress,
    PorkelonLiquidityLocker: liquidityLockerAddress,
    PorkelonMarketingVault: vaultAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };
  await fs.writeFile(
    path.resolve(__dirname, "../deployments.json"),
    JSON.stringify(artifacts, null, 2)
  );
  console.log("Deployment artifacts saved to deployments.json");
}

main()
  .then(() => {
    console.log("Deployment completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
