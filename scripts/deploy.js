/**
 * scripts/deploy.js
 *
 * Robust deployment script for PorkelonToken
 * - Loads environment variables (dotenv)
 * - Validates MARKETING_WALLET address
 * - Prints deploy diagnostics (network, deployer, balance, gas estimate)
 * - Waits for configurable confirmations post-deployment
 * - Attempts Etherscan verification if ETHERSCAN_API_KEY is present
 * - Exports main() for tests/scripts; logs errors clearly
 *
 * Usage:
 *   MARKETING_WALLET=0x... npx hardhat run --network <network> scripts/deploy.js
 *
 * Environment variables:
 *   MARKETING_WALLET (required)
 *   WAIT_CONFIRMATIONS (optional, default: 1)
 *   ETHERSCAN_API_KEY (optional, for verification)
 */

'use strict';
require('dotenv').config();

const hre = require('hardhat');
const { ethers, network } = hre;

async function main() {
  // ENV setup
  const marketingWallet = process.env.MARKETING_WALLET;
  const waitConfirmations = Number(process.env.WAIT_CONFIRMATIONS || 1);
  const etherscanKey = process.env.ETHERSCAN_API_KEY;

  // Validation
  if (!marketingWallet) throw new Error('MARKETING_WALLET not set in environment.');
  if (!ethers.utils.isAddress(marketingWallet)) throw new Error(`Invalid MARKETING_WALLET: ${marketingWallet}`);

  // Diagnostics
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  const balance = await deployer.getBalance();

  console.log('------------------------------------------------------');
  console.log(`Network:   ${network.name} (chainId: ${network.config.chainId || 'unknown'})`);
  console.log(`Deployer:  ${deployerAddress}`);
  console.log(`Balance:   ${ethers.utils.formatEther(balance)} ETH`);
  console.log(`Marketing wallet: ${marketingWallet}`);
  console.log('Preparing contract factory...');

  // Factory and Gas Estimate
  const Porkelon = await ethers.getContractFactory('PorkelonToken');
  const constructorArgs = [marketingWallet];
  try {
    const gasEstimate = await Porkelon.signer.estimateGas(Porkelon.getDeployTransaction(...constructorArgs));
    console.log(`Estimated deployment gas: ${gasEstimate.toString()}`);
  } catch (e) {
    console.warn('Cannot estimate gas:', e.message || e);
  }

  // Deploy
  console.log('Deploying PorkelonToken...');
  const token = await Porkelon.deploy(...constructorArgs);
  console.log(`Transaction hash: ${token.deployTransaction.hash}`);
  await token.deployed();
  if (waitConfirmations > 0) {
    console.log(`Waiting for ${waitConfirmations} confirmation(s)...`);
    await token.deployTransaction.wait(waitConfirmations);
  }
  console.log(`✅ PorkelonToken deployed at: ${token.address}`);
  console.log(`Constructor args: ${JSON.stringify(constructorArgs)}`);
  console.log('------------------------------------------------------');

  // Etherscan Verification
  if (etherscanKey && !['hardhat', 'localhost'].includes(network.name)) {
    console.log('Verifying on Etherscan...');
    try {
      await hre.run('verify:verify', { address: token.address, constructorArguments: constructorArgs });
      console.log('✅ Verification submitted/succeeded.');
    } catch (e) {
      console.warn('Verification failed or already verified:', e.message || e);
    }
  } else if (!etherscanKey) {
    console.log('ETHERSCAN_API_KEY not set, skipping verification.');
  } else {
    console.log('Local network, skipping verification.');
  }
  console.log('------------------------------------------------------');

  // Return for scripting/tests
  return { token, deployerAddress };
}

module.exports = main;

if (require.main === module) {
  main()
    .then(() => {
      console.log('Deployment completed.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('Deployment error:', err);
      process.exit(1);
    });
}
