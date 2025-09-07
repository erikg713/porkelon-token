/**
 * scripts/deploy.js
 *
 * Improved deployment script for PorkelonToken
 * - Loads environment variables via dotenv
 * - Validates constructor args (MARKETING_WALLET)
 * - Prints useful deploy diagnostics (network, deployer, balance, gas estimate)
 * - Waits configurable confirmations before finishing
 * - Attempts Etherscan verification automatically when ETHERSCAN_API_KEY is present
 * - Better error handling and clearer logs
 *
 * Usage:
 *   MARKETING_WALLET=0x... npx hardhat run --network <network> scripts/deploy.js
 *
 * Optional environment variables:
 *   WAIT_CONFIRMATIONS (default: 1)
 *   ETHERSCAN_API_KEY (for automatic verification, if supported for the network)
 */

'use strict';

require('dotenv').config();
const hre = require('hardhat');
const { ethers, network } = hre;

async function main() {
  const waitConfirmations = Number(process.env.WAIT_CONFIRMATIONS || 1);

  // Resolve signer
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();

  console.log('------------------------------------------------------');
  console.log(`Network:   ${network.name} (chainId: ${network.config.chainId || 'unknown'})`);
  console.log(`Deployer:  ${deployerAddress}`);
  const balance = await deployer.getBalance();
  console.log(`Balance:   ${ethers.utils.formatEther(balance)} ETH`);
  console.log('------------------------------------------------------');

  // Validate MARKETING_WALLET
  const marketingWallet = process.env.MARKETING_WALLET;
  if (!marketingWallet) {
    throw new Error('Missing MARKETING_WALLET in environment (.env). Set MARKETING_WALLET=0x...');
  }
  if (!ethers.utils.isAddress(marketingWallet)) {
    throw new Error(`Invalid MARKETING_WALLET address: ${marketingWallet}`);
  }
  console.log(`Marketing wallet: ${marketingWallet}`);
  console.log('Preparing contract factory...');

  // Get contract factory and estimate deployment gas
  const Porkelon = await ethers.getContractFactory('PorkelonToken');
  const constructorArgs = [marketingWallet];

  // Estimate gas for deployment (best-effort)
  let gasEstimate;
  try {
    gasEstimate = await Porkelon.signer.estimateGas(Porkelon.getDeployTransaction(...constructorArgs));
    console.log(`Estimated deployment gas: ${gasEstimate.toString()}`);
  } catch (err) {
    console.warn('Could not estimate deployment gas:', err.message || err);
  }

  console.log('Deploying PorkelonToken...');

  // Deploy the contract
  const token = await Porkelon.deploy(...constructorArgs);
  console.log(`Transaction hash: ${token.deployTransaction.hash}`);
  console.log('Waiting for contract to be mined...');

  await token.deployed();

  // Wait additional confirmations if requested (useful for verification on Etherscan)
  if (waitConfirmations > 0) {
    console.log(`Waiting for ${waitConfirmations} confirmation(s)...`);
    await token.deployTransaction.wait(waitConfirmations);
  }

  console.log('✅ PorkelonToken deployed at:', token.address);
  console.log(`Constructor args: ${JSON.stringify(constructorArgs)}`);
  console.log('------------------------------------------------------');

  // Attempt Etherscan verification when API key present and network is not a local network
  const etherscanKey = process.env.ETHERSCAN_API_KEY;
  const localNets = ['hardhat', 'localhost'];
  if (etherscanKey && !localNets.includes(network.name)) {
    console.log('ETHERSCAN_API_KEY found — attempting verification (this may take a minute)...');
    try {
      // run verify task provided by hardhat-etherscan plugin
      await hre.run('verify:verify', {
        address: token.address,
        constructorArguments: constructorArgs,
      });
      console.log('✅ Verification submitted/succeeded.');
    } catch (verifyErr) {
      console.warn('Verification failed or already verified:', verifyErr.message || verifyErr);
    }
    console.log('------------------------------------------------------');
  } else if (!etherscanKey) {
    console.log('ETHERSCAN_API_KEY not set — skipping automatic verification.');
    console.log('If you want verification, set ETHERSCAN_API_KEY in .env and rerun (or run manually).');
    console.log('------------------------------------------------------');
  } else {
    console.log(`Skipping verification on local network "${network.name}".`);
    console.log('------------------------------------------------------');
  }

  // Return deployed contract object for programmatic use (tests / scripts)
  return { token, deployerAddress };
}

// Allow importing of the function from other scripts/tests
module.exports = main;

// Run when executed directly
if (require.main === module) {
  main()
    .then(() => {
      console.log('Deployment script finished successfully.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('Deployment failed:', err);
      process.exit(1);
    });
}
