const { ethers, upgrades } = require("hardhat");
const USDT_ADDRESS = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";  // Polygon USDT

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // 1. Deploy Token (upgradeable proxy)
  const PorkelonToken = await ethers.getContractFactory("PorkelonToken");
  const liquidityWallet = "0xYourLiquidityWalletAddress";  // Replace
  const marketingWallet = "0xYourMarketingWalletAddress";  // Replace
  const tokenProxy = await upgrades.deployProxy(PorkelonToken, [liquidityWallet, marketingWallet], { initializer: 'initialize' });
  await tokenProxy.waitForDeployment();
  const tokenAddress = await tokenProxy.getAddress();
  console.log("PorkelonToken deployed to:", tokenAddress);

  // 2. Distribute allocations (call after deploy)
  const token = await ethers.getContractAt("PorkelonToken", tokenAddress);
  const presaleAddress = await deployPresale(tokenAddress);  // Deploy presale next
  const airdropAddress = await deployAirdrop(tokenAddress);
  const stakingAddress = await deployStaking(tokenAddress);
  const liquidityLockerAddress = await deployLiquidityLocker(tokenAddress);
  // MarketingVault doesn't need tokens upfront—deploy separately

  await token.distributeAllocations(presaleAddress, airdropAddress, stakingAddress, liquidityLockerAddress);
  console.log("Allocations distributed!");

  // 3. Deploy Presale
  async function deployPresale(tokenAddr) {
    const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
    const fundsWallet = "0xYourFundsWallet";  // e.g., team
    const maticRate = ethers.parseEther("1000000");  // 1M PORK per MATIC—tune
    const usdtRate = ethers.parseEther("1000");  // 1K PORK per USDT—tune
    const cap = ethers.parseEther("10000000000");  // 10B PORK cap
    const presale = await PorkelonPresale.deploy(tokenAddr, USDT_ADDRESS, fundsWallet, maticRate, usdtRate, cap);
    await presale.waitForDeployment();
    console.log("Presale deployed to:", await presale.getAddress());
    return await presale.getAddress();
  }

  // 4. Deploy Airdrop (5% allocation auto-sent via distribute)
  async function deployAirdrop(tokenAddr) {
    const PorkelonAirdrop = await ethers.getContractFactory("PorkelonAirdrop");
    const airdrop = await PorkelonAirdrop.deploy(token, ethers.parseEther("5000000000"));  // 5B pool
    await airdrop.waitForDeployment();
    console.log("Airdrop deployed to:", await airdrop.getAddress());
    return await airdrop.getAddress();
  }

  // 5. Deploy Staking (10% allocation)
  async function deployStaking(tokenAddr) {
    const PorkelonStakingRewards = await ethers.getContractFactory("PorkelonStakingRewards");
    const staking = await PorkelonStakingRewards.deploy(token, token, ethers.parseEther("10000000000"));  // 10B pool
    await staking.waitForDeployment();
    console.log("Staking deployed to:", await staking.getAddress());
    return await staking.getAddress();
  }

  // 6. Deploy Liquidity Locker (40% allocation)
  async function deployLiquidityLocker(tokenAddr) {
    const PorkelonLiquidityLocker = await ethers.getContractFactory("PorkelonLiquidityLocker");
    const beneficiary = "0xYourLPProviderWallet";  // e.g., for Uniswap/QuickSwap LP
    const locker = await PorkelonLiquidityLocker.deploy(token, beneficiary, ethers.parseEther("40000000000"));  // 40B
    await locker.waitForDeployment();
    console.log("Locker deployed to:", await locker.getAddress());
    return await locker.getAddress();
  }

  // 7. Deploy Marketing Vault (10% allocation already to marketingWallet)
  const PorkelonMarketingVault = await ethers.getContractFactory("PorkelonMarketingVault");
  const vault = await PorkelonMarketingVault.deploy(token, ethers.parseEther("10000000000"));  // 10B
  await vault.waitForDeployment();
  console.log("Marketing Vault deployed to:", await vault.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
