const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

async function main() {
  const {
    TEAM_WALLET,
    PRESALE_WALLET,
    AIRDROP_WALLET,
    STAKING_WALLET,
    REWARDS_WALLET,
    LIQUIDITY_WALLET
  } = process.env;

  console.log("Deploying Porkelon (proxy + presale) with upgradeability...");

  // Deploy UUPS Proxy for Porkelon
  const Porkelon = await ethers.getContractFactory("Porkelon");
  const porkelon = await upgrades.deployProxy(
    Porkelon,
    [
      TEAM_WALLET,
      PRESALE_WALLET,
      AIRDROP_WALLET,
      STAKING_WALLET,
      REWARDS_WALLET,
      LIQUIDITY_WALLET
    ],
    { kind: "uups" }
  );
  await porkelon.deployed();
  console.log("✅ Porkelon Proxy deployed to:", await porkelon.getAddress());

  // Deploy Presale contract
  const USDT = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"; // Polygon USDT
  const presaleCap = ethers.utils.parseUnits("10000000000", 18); // 10B PORK
  const maticRate = ethers.BigNumber.from("1000000"); // 1M PORK per MATIC
  const usdtRate = ethers.BigNumber.from("1000000"); // 1M PORK per USDT

  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presale = await PorkelonPresale.deploy(
    await porkelon.getAddress(),
    USDT,
    TEAM_WALLET,
    maticRate,
    usdtRate,
    presaleCap
  );
  await presale.deployed();
  console.log("✅ PorkelonPresale deployed to:", presale.address);

  console.log("⚠️ Remember: transfer presale tokens from PRESALE_WALLET to presale contract manually.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
