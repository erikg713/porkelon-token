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
