// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

const USDT_ADDRESS = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"; // Polygon USDT

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Wallets (replace with your actual addresses)
  const teamWallet = "0xYourTeamWalletHere";
  const marketingWallet = "0xYourMarketingWalletHere";
  const liquidityWallet = "0xYourLiquidityWalletHere";

  // 1. Deploy Porkelon (upgradeable proxy)
  const Porkelon = await ethers.getContractFactory("Porkelon");
  const porkelonProxy = await upgrades.deployProxy(
    Porkelon,
    [teamWallet, marketingWallet, liquidityWallet], 
    { initializer: "initialize", kind: "uups" }
  );
  await porkelonProxy.waitForDeployment();
  const porkelonAddress = await porkelonProxy.getAddress();
  console.log("✅ Porkelon deployed to:", porkelonAddress);

  // 2. Deploy Presale
  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presaleCap = ethers.parseEther("10000000000"); // 10B cap
  const presale = await PorkelonPresale.deploy(
    porkelonAddress,
    USDT_ADDRESS,
    teamWallet,                     // funds wallet
    ethers.parseEther("1000000"),   // 1M PORK per MATIC
    ethers.parseEther("1000"),      // 1k PORK per USDT
    presaleCap
  );
  await presale.waitForDeployment();
  const presaleAddress = await presale.getAddress();
  console.log("✅ PorkelonPresale deployed to:", presaleAddress);

  // 3. Deploy Airdrop
  const PorkelonAirdrop = await ethers.getContractFactory("PorkelonAirdrop");
  const airdrop = await PorkelonAirdrop.deploy(porkelonAddress, ethers.parseEther("5000000000")); // 5B
  await airdrop.waitForDeployment();
  const airdropAddress = await airdrop.getAddress();
  console.log("✅ PorkelonAirdrop deployed to:", airdropAddress);

  // 4. Deploy Staking
  const PorkelonStaking = await ethers.getContractFactory("PorkelonStakingRewards");
  const staking = await PorkelonStaking.deploy(porkelonAddress, porkelonAddress, ethers.parseEther("10000000000")); // 10B
  await staking.waitForDeployment();
  const stakingAddress = await staking.getAddress();
  console.log("✅ PorkelonStaking deployed to:", stakingAddress);

  // 5. Deploy Liquidity Locker
  const PorkelonLiquidityLocker = await ethers.getContractFactory("PorkelonLiquidityLocker");
  const locker = await PorkelonLiquidityLocker.deploy(
    porkelonAddress,
    liquidityWallet,
    ethers.parseEther("40000000000") // 40B
  );
  await locker.waitForDeployment();
  const lockerAddress = await locker.getAddress();
  console.log("✅ PorkelonLiquidityLocker deployed to:", lockerAddress);

  // 6. Deploy Marketing Vault
  const PorkelonMarketingVault = await ethers.getContractFactory("PorkelonMarketingVault");
  const vault = await PorkelonMarketingVault.deploy(porkelonAddress, ethers.parseEther("10000000000")); // 10B
  await vault.waitForDeployment();
  const vaultAddress = await vault.getAddress();
  console.log("✅ PorkelonMarketingVault deployed to:", vaultAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
