// scripts/deploy.js
const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const {
    TEAM_WALLET,
    PRESALE_WALLET,
    AIRDROP_WALLET,
    STAKING_WALLET,
    REWARDS_WALLET,
    LIQUIDITY_WALLET,
  } = process.env;

  // sanity
  if (!TEAM_WALLET || !PRESALE_WALLET || !AIRDROP_WALLET || !STAKING_WALLET || !REWARDS_WALLET || !LIQUIDITY_WALLET) {
    throw new Error("Fill all allocation wallet env variables in .env");
  }

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Porkelon = await hre.ethers.getContractFactory("PorkelonPolygon");
  console.log("Deploying PorkelonPolygon...");
  const porkelon = await Porkelon.deploy(
    TEAM_WALLET,
    PRESALE_WALLET,
    AIRDROP_WALLET,
    STAKING_WALLET,
    REWARDS_WALLET,
    LIQUIDITY_WALLET
  );

  await porkelon.deployed();
  console.log("✅ PorkelonPolygon deployed at:", porkelon.address);

  // print allocations
  const allocations = await porkelon.allocations();
  console.log("Allocations (raw wei):");
  console.log(" team:", allocations[0].toString());
  console.log(" presale:", allocations[1].toString());
  console.log(" airdrop:", allocations[2].toString());
  console.log(" staking:", allocations[3].toString());
  console.log(" rewards:", allocations[4].toString());
  console.log(" liquidity:", allocations[5].toString());

  // convenience - print human readable numbers
  const toReadable = (bn) => hre.ethers.utils.formatUnits(bn, 18);
  console.log("Allocations (human):");
  console.log(" team:", toReadable(allocations[0]));
  console.log(" presale:", toReadable(allocations[1]));
  console.log(" airdrop:", toReadable(allocations[2]));
  console.log(" staking:", toReadable(allocations[3]));
  console.log(" rewards:", toReadable(allocations[4]));
  console.log(" liquidity:", toReadable(allocations[5]));

  // team vesting start & liquidity release info
  const teamInfo = await porkelon.teamInfo();
  const liquidity = await porkelon.liquidityInfo();
  console.log("team vesting start:", teamInfo[3].toString(), "duration:", teamInfo[4].toString());
  console.log("liquidity release timestamp:", liquidity[1].toString());

  // store deployed address to file (optional)
  const fs = require("fs");
  fs.writeFileSync("deployed-address.txt", porkelon.address);

  console.log("Done.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
