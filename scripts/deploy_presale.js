const { ethers } = require("hardhat");

async function main() {
  const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
  const presale = await PorkelonPresale.deploy(
    "0xYourPorkelonAddressHere",
    1000000000000000n, // Example tokenPrice (1e15 wei/token)
    100000000000000000n, // minPurchase 0.1 POL
    10000000000000000000n, // maxPurchase 10 POL
    Math.floor(Date.now() / 1000) + 3600, // Start in 1 hour
    Math.floor(Date.now() / 1000) + 86400 * 7, // End in 7 days
    30000000000n * (10n ** 18n) // 30B tokens
  );
  console.log("Presale deployed to:", await presale.getAddress());
}

main();
