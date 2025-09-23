// scripts/deploy.js
const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const { ethers } = hre;
  const walletAddress = (await ethers.getSigners())[0].address;
  console.log("Deploying from:", walletAddress);

  // Compile
  await hre.run("compile");

  // Factory
  const Porkelon = await ethers.getContractFactory("Porkelon");

  // Total supply: 100,000,000,000 tokens with 18 decimals
  const totalSupply = ethers.utils.parseUnits("100000000000", 18);

  console.log("Deploying Porkelon with total supply:", totalSupply.toString());

  const contract = await Porkelon.deploy(totalSupply);
  await contract.deployed();

  console.log("Porkelon deployed at:", contract.address);
  console.log("Done.");
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });

const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

async function main() {
  const { TEAM_WALLET, PRESALE_WALLET, AIRDROP_WALLET, STAKING_WALLET, REWARDS_WALLET, LIQUIDITY_WALLET } = process.env;

  // Deploy Porkelon proxy
  const Porkelon = await ethers.getContractFactory("Porkelon");
  const porkelon = await upgrades.deployProxy(Porkelon, [
    TEAM_WALLET,
    PRESALE_WALLET,
    AIRDROP_WALLET,
    STAKING_WALLET,
    REWARDS_WALLET,
    LIQUIDITY_WALLET
  ], { kind: 'uups' });
  await porkelon.waitForDeployment();
  console.log("Porkelon Proxy deployed to:", await porkelon.getAddress());

  // Deploy Presale (example rates: 1M PORK per MATIC, 1M PORK per USDT; cap = 10B PORK)
  const USDT = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";
  const presaleCap = ethers.parseUnits("10000000000", 18); // 10B PORK
  const maticRate = ethers.parseUnits("1000000", 0); // Adjust as needed
  const usdtRate = ethers.parseUnits("1000000", 0); // Adjust as needed
  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presale = await PorkelonPresale.deploy(
    await porkelon.getAddress(),
    USDT,
    TEAM_WALLET, // Funds go to team
    maticRate,
    usdtRate,
    presaleCap
  );
  await presale.waitForDeployment();
  console.log("PorkelonPresale deployed to:", await presale.getAddress());

  // Transfer presale allocation from presale_wallet to presale contract (assume you control presale_wallet; otherwise, manual tx)
  // For automation, impersonate if on testnet or use multisig
  console.log("Manually transfer presale tokens from PRESALE_WALLET to presale contract.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
