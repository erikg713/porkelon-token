const { ethers, upgrades } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("Fetching Porkelon and PorkelonPresale addresses...");

  // Load deployer and network
  const [deployer] = await ethers.getSigners();
  const network = (await ethers.provider.getNetwork()).name;
  console.log(`Network: ${network}`);
  console.log(`Deployer account: ${deployer.address}`);

  // Configuration
  const PROXY_ADDRESS = process.env.PORKELON_PROXY_ADDRESS || "0xYOUR_PROXY_ADDRESS";
  const deploymentsPath = path.resolve(__dirname, "../deployments.json");

  // Validate proxy address
  if (!ethers.isAddress(PROXY_ADDRESS) || PROXY_ADDRESS === "0xYOUR_PROXY_ADDRESS") {
    console.warn("Warning: Invalid or unset PORKELON_PROXY_ADDRESS in .env. Attempting to read from deployments.json.");
  }

  // Read deployments.json
  let deployments = {};
  try {
    deployments = JSON.parse(await fs.readFile(deploymentsPath, "utf8"));
    console.log("\nAddresses from deployments.json:");
    console.log(`Porkelon Proxy: ${deployments.PorkelonProxy || "Not found"}`);
    console.log(`Porkelon Implementation: ${deployments.PorkelonImplementation || "Not found"}`);
    console.log(`PorkelonPresale: ${deployments.PorkelonPresale || "Not found"}`);
    console.log(`Upgrade Timestamp: ${deployments.upgradeTimestamp || "Not found"}`);
    console.log(`Presale Deploy Timestamp: ${deployments.presaleDeployTimestamp || "Not found"}`);
  } catch (e) {
    console.error("Error: deployments.json not found or invalid. Please run the deployment script first.");
    console.log("Attempting to fetch implementation address from blockchain...");
  }

  // Verify proxy implementation address on-chain
  if (ethers.isAddress(PROXY_ADDRESS)) {
    try {
      const proxyCode = await ethers.provider.getCode(PROXY_ADDRESS);
      if (proxyCode === "0x") {
        console.error(`Error: No contract found at proxy address: ${PROXY_ADDRESS}`);
      } else {
        const implementationAddress = await upgrades.erc1967.getImplementationAddress(PROXY_ADDRESS);
        console.log("\nOn-chain verification:");
        console.log(`Porkelon Proxy (from .env): ${PROXY_ADDRESS}`);
        console.log(`Current Implementation (from blockchain): ${implementationAddress}`);
        
        // Check if implementation matches deployments.json
        if (deployments.PorkelonImplementation && deployments.PorkelonImplementation !== implementationAddress) {
          console.warn("Warning: Implementation address in deployments.json does not match on-chain implementation!");
        }
      }
    } catch (e) {
      console.error(`Error fetching implementation address for proxy ${PROXY_ADDRESS}: ${e.message}`);
    }
  } else {
    console.error("Error: Cannot verify implementation without a valid PORKELON_PROXY_ADDRESS.");
  }

  // Suggest next steps
  console.log("\nNext steps:");
  if (ethers.isAddress(PROXY_ADDRESS)) {
    console.log(`Verify Porkelon on PolygonScan (network: ${network}):`);
    console.log(`npx hardhat verify --network ${network} ${deployments.PorkelonImplementation || PROXY_ADDRESS}`);
    if (deployments.PorkelonPresale) {
      console.log(`Verify PorkelonPresale on PolygonScan (network: ${network}):`);
      console.log(`npx hardhat verify --network ${network} ${deployments.PorkelonPresale}`);
    }
  } else {
    console.log("Set PORKELON_PROXY_ADDRESS in .env or run the deployment script to generate deployments.json.");
  }
}

main()
  .then(() => {
    console.log("Address retrieval completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error during address retrieval:", error);
    process.exit(1);
  });
