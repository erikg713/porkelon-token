// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("Starting Porkelon ecosystem deployment...");
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("POL Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  const config = {
    teamWallet: process.env.TEAM_WALLET,
    presaleWallet: process.env.PRESALE_WALLET,
    airdropWallet: process.env.AIRDROP_WALLET,
    stakingWallet: process.env.STAKING_WALLET,
    rewardsWallet: process.env.REWARDS_WALLET,
    marketingWallet: process.env.MARKETING_WALLET,
    liquidityWallet: process.env.LIQUIDITY_WALLET,
    fundsWallet: process.env.FUNDS_WALLET || deployer.address,
    usdtAddress: process.env.USDT_ADDRESS,
    tokenPriceMatic: ethers.parseEther("0.000001"), // 1M PORK/MATIC
    tokenPriceUsdt: ethers.parseEther("0.001"), // 1K PORK/USDT
    minPurchase: ethers.parseEther("0.1"),
    maxPurchase: ethers.parseEther("10"),
    presaleCap: ethers.parseEther("10000000000"), // 10B PORK
    airdropPool: ethers.parseEther("5000000000"), // 5B PORK
    stakingPool: ethers.parseEther("10000000000"), // 10B PORK
    liquidityLock: ethers.parseEther("40000000000"), // 40B PORK
    marketingVault: ethers.parseEther("10000000000"), // 10B PORK
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
  const presale = await upgrades.deployProxy(
    PorkelonPresale,
    [
      tokenAddress,
      config.usdtAddress,
      config.tokenPriceMatic,
      config.tokenPriceUsdt,
      config.minPurchase,
      config.maxPurchase,
      startTime,
      endTime,
      config.presaleCap
    ],
    { initializer: "initialize" }
  );
  await presale.waitForDeployment();
  const presaleAddress = await presale.getAddress();
  console.log("PorkelonPresale deployed to:", presaleAddress);

  // Deploy PorkelonAirdrop
  console.log("Deploying PorkelonAirdrop...");
  const PorkelonAirdrop = await ethers.getContractFactory("PorkelonAirdrop");
  const airdrop = await upgrades.deployProxy(
    PorkelonAirdrop,
    [tokenAddress, config.airdropPool],
    { initializer: "initialize" }
  );
  await airdrop.waitForDeployment();
  const airdropAddress = await airdrop.getAddress();
  console.log("PorkelonAirdrop deployed to:", airdropAddress);

  // Deploy PorkelonStakingRewards
  console.log("Deploying PorkelonStakingRewards...");
  const PorkelonStakingRewards = await ethers.getContractFactory("PorkelonStakingRewards");
  const staking = await upgrades.deployProxy(
    PorkelonStakingRewards,
    [tokenAddress, config.rewardsWallet, config.stakingPool],
    { initializer: "initialize" }
  );
  await staking.waitForDeployment();
  const stakingAddress = await staking.getAddress();
  console.log("PorkelonStakingRewards deployed to:", stakingAddress);

  // Deploy PorkelonLiquidityLocker
  console.log("Deploying PorkelonLiquidityLocker...");
  const PorkelonLiquidityLocker = await ethers.getContractFactory("PorkelonLiquidityLocker");
  const locker = await upgrades.deployProxy(
    PorkelonLiquidityLocker,
    [tokenAddress, config.liquidityWallet, config.liquidityLock],
    { initializer: "initialize" }
  );
  await locker.waitForDeployment();
  const liquidityLockerAddress = await locker.getAddress();
  console.log("PorkelonLiquidityLocker deployed to:", liquidityLockerAddress);

  // Deploy PorkelonMarketingVault
  console.log("Deploying PorkelonMarketingVault...");
  const PorkelonMarketingVault = await ethers.getContractFactory("PorkelonMarketingVault");
  const vault = await upgrades.deployProxy(
    PorkelonMarketingVault,
    [tokenAddress, config.marketingWallet, config.vestingDuration],
    { initializer: "initialize" }
  );
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

  // Verify balances
  console.log("Verifying token balances...");
  const balances = {
    team: await porkelon.balanceOf(config.teamWallet),
    presale: await porkelon.balanceOf(config.presaleWallet),
    airdrop: await porkelon.balanceOf(config.airdropWallet),
    staking: await porkelon.balanceOf(config.stakingWallet),
    marketing: await porkelon.balanceOf(config.marketingWallet),
    liquidity: await porkelon.balanceOf(config.liquidityWallet)
  };
  console.log("Balances:");
  for (const [key, balance] of Object.entries(balances)) {
    console.log(`${key}: ${ethers.formatEther(balance)} PORK`);
  }
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
