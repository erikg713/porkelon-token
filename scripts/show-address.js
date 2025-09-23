// scripts/show-address.js
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
