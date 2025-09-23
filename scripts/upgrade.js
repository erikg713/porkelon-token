// scripts/upgrade.js
/**
 * Upgrade script (UUPS) for Porkelon proxy on Polygon / Mumbai
 *
 * Usage:
 *   # 1) compile and run a test on mumbai
 *   npx hardhat run scripts/upgrade.js --network mumbai
 *
 *   # 2) upgrade on polygon mainnet
 *   npx hardhat run scripts/upgrade.js --network polygon
 *
 * Required env vars (.env):
 *   PRIVATE_KEY        - deployer private key (0x...)
 *   RPC_URL            - RPC for the network (handled via hardhat.networks)
 *   PROXY_ADDRESS      - address of the deployed proxy to upgrade
 *   POLYGONSCAN_API_KEY - optional, for verification
 *
 * Notes:
 * - Ensure the new implementation contract has a compatible storage layout.
 * - Test thoroughly on Mumbai before performing mainnet upgrades.
 */

const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const { upgrades, ethers } = hre;

  // Simple safety checks
  const proxyAddress = process.env.PROXY_ADDRESS;
  if (!proxyAddress) {
    console.error("ERROR: PROXY_ADDRESS must be set in .env");
    process.exit(1);
  }

  const networkName = hre.network.name;
  console.log("==========================================");
  console.log(`🛠  Running UUPS upgrade on network: ${networkName}`);
  console.log("Proxy address:", proxyAddress);
  console.log("Deployer:", (await ethers.getSigners())[0].address);
  console.log("==========================================");

  // Compile
  console.log("Compiling contracts...");
  await hre.run("compile");

  // IMPORTANT: replace 'Porkelon' with the contract name you want to deploy as the new implementation
  const Implementation = await ethers.getContractFactory("Porkelon");
  console.log("Deploying new implementation contract (bytecode + init)...");
  // We don't call initialize here — UUPS implementations should avoid initializing logic in constructor.
  const impl = await Implementation.deploy();
  await impl.deployed();
  console.log("✅ New implementation (temporary) deployed at:", impl.address);

  // OPTIONAL: if you want to run verification of the raw implementation contract before upgrade
  if (process.env.POLYGONSCAN_API_KEY) {
    console.log("Attempting to verify new implementation on Polygonscan/Etherscan...");
    try {
      await hre.run("verify:verify", {
        address: impl.address,
        constructorArguments: [], // add args if the implementation contract has constructor args (rare)
      });
      console.log("✅ Implementation verified.");
    } catch (e) {
      console.warn("⚠️ Verification failed/skipped:", e.message || e);
    }
  }

  // Now perform the upgrade on the proxy
  console.log("Preparing upgrade of proxy -> new implementation...");
  // Call upgradeProxy to set the proxy implementation to the new contract (UUPS)
  // Note: upgrades.upgradeProxy expects the proxy address and the contract factory (not the deployed impl address).
  const upgraded = await upgrades.upgradeProxy(proxyAddress, Implementation);

  // Wait for deployment tx to be mined (if available)
  try {
    if (upgraded.deployTransaction) {
      console.log("Waiting for upgrade transaction to confirm...");
      await upgraded.deployTransaction.wait();
    }
  } catch (e) {
    // ignore if no deployTransaction
  }

  console.log("✅ Proxy upgraded. Proxy address still:", proxyAddress);

  // Fetch implementation address per EIP-1967 to confirm
  try {
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("Implementation (current) address:", implAddress);
  } catch (e) {
    console.warn("Could not fetch implementation address:", e.message || e);
  }

  console.log("Upgrade finished. IMPORTANT: run tests and verify behavior immediately.");
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error("Upgrade script failed:", err);
    process.exit(1);
  });
