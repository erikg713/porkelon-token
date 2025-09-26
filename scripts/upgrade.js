const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Upgrading with account:", deployer.address);

  // Replace with the address of the deployed PorkelonToken proxy
  const PROXY_ADDRESS = "0xYOUR_PROXY_ADDRESS"; // Set to the deployed proxy address from deploy.js

  // Ensure the deployer is the DEV_WALLET with UPGRADER_ROLE
  const DEV_WALLET = "0xBc2E051f3Dedcd0B9dDCA2078472f513a39df2C6";
  if (deployer.address.toLowerCase() !== DEV_WALLET.toLowerCase()) {
    throw new Error("Deployer must be DEV_WALLET with UPGRADER_ROLE");
  }

  // Get the new implementation contract factory
  const PorkelonToken = await ethers.getContractFactory("PorkelonToken");

  // Upgrade the proxy to the new implementation
  console.log("Upgrading PorkelonToken at proxy:", PROXY_ADDRESS);
  const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, PorkelonToken, { kind: "uups" });
  await upgraded.deployed();
  console.log("PorkelonToken upgraded successfully");

  // Log the implementation address
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(PROXY_ADDRESS);
  console.log("New implementation address:", implementationAddress);

  // Optional: Verify the new implementation on PolygonScan
  console.log("Run the following to verify on PolygonScan:");
  console.log(`npx hardhat verify --network polygon ${implementationAddress}`);
}

main().catch((error) => {
  console.error("Error during upgrade:", error);
  process.exitCode = 1;
});
