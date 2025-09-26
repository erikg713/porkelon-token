// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy Porkelon (upgradeable)
  const Porkelon = await ethers.getContractFactory("Porkelon");
  const teamWallet = "0xYourTeamWalletHere"; // Replace
  const presaleWallet = "0xYourPresaleWalletHere"; // Replace or use below
  const airdropWallet = "0xYourAirdropWalletHere"; // Replace or use below
  const stakingWallet = "0xYourStakingWalletHere"; // Replace
  const rewardsWallet = "0xYourRewardsWalletHere"; // Replace
  const liquidityWallet = "0xYourLiquidityWalletHere"; // Replace
  const porkelon = await upgrades.deployProxy(
    Porkelon,
    [teamWallet, presaleWallet, airdropWallet, stakingWallet, rewardsWallet, liquidityWallet],
    { initializer: "initialize", kind: "uups" }
  );
  await porkelon.waitForDeployment();
  const tokenAddress = await porkelon.getAddress();
  console.log("Porkelon deployed to:", tokenAddress);

  // Deploy PorkelonPresale
  const tokenPrice = ethers.parseEther("0.000001"); // 1M PORK per MATIC (1e15 wei/token)
  const minPurchase = ethers.parseEther("0.1"); // 0.1 MATIC
  const maxPurchase = ethers.parseEther("10"); // 10 MATIC
  const startTime = Math.floor(Date.now() / 1000) + 3600; // Start in 1 hour
  const endTime = startTime + 86400 * 7; // End in 7 days
  const cap = ethers.parseEther("10000000000"); // 10B PORK (matches Porkelon.sol allocation)
  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presale = await PorkelonPresale.deploy(
    tokenAddress,
    tokenPrice,
    minPurchase,
    maxPurchase,
    startTime,
    endTime,
    cap
  );
  await presale.waitForDeployment();
  const presaleAddress = await presale.getAddress();
  console.log("PorkelonPresale deployed to:", presaleAddress);

  // Deploy PorkelonAirdrop
  const airdropPool = ethers.parseEther("10000000000"); // 10B PORK (10% of 100B)
  const PorkelonAirdrop = await ethers.getContractFactory("PorkelonAirdrop");
  const airdrop = await PorkelonAirdrop.deploy(tokenAddress, airdropPool);
  await airdrop.waitForDeployment();
  const airdropAddress = await airdrop.getAddress();
  console.log("PorkelonAirdrop deployed to:", airdropAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
