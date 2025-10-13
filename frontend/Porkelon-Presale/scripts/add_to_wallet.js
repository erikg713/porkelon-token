// scripts/add_to_wallet.js
// Utility script for the Porkelon Presale frontend: Adds the $PORK token to MetaMask (or compatible wallets) via ethers.js.
// Useful for users post-deployment to easily import the custom ERC-20 token.
// Run with: node scripts/add_to_wallet.js (after setting env vars).
// Note: This script interacts with the browser's ethereum provider (e.g., MetaMask). Open in a browser console or integrate into the dApp UI for better UX.

const { ethers } = require('ethers');

// Configuration - Update with actual Porkelon details
const TOKEN_ADDRESS = process.env.VITE_PORK_TOKEN_ADDRESS || '0x7f024bd81c22dafae5ecca46912acd94511210d8'; // Deployed contract
const TOKEN_SYMBOL = 'PORK';
const TOKEN_DECIMALS = 18;
const TOKEN_IMAGE = 'https://your-domain.com/porkelon-logo.png'; // Optional: Host a 256x256 PNG logo (IPFS recommended for decentralization)

// Check if ethereum provider is available (MetaMask injected)
if (!window.ethereum) {
  console.error('MetaMask or compatible wallet not detected. Please install it!');
  process.exit(1);
}

// Request wallet connection if needed
async function addTokenToWallet() {
  try {
    // Connect provider
    const provider = new ethers.BrowserProvider(window.ethereum);
    await provider.send('eth_requestAccounts', []); // Prompt user to connect

    // Use wallet_addEthereumChain equivalent for token: wallet_watchAsset
    const wasAdded = await window.ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address: TOKEN_ADDRESS,
          symbol: TOKEN_SYMBOL,
          decimals: TOKEN_DECIMALS,
          image: TOKEN_IMAGE,
        },
      },
    });

    if (wasAdded) {
      console.log(`${TOKEN_SYMBOL} token added to your wallet successfully!`);
    } else {
      console.log('Token addition was rejected or failed.');
    }
  } catch (error) {
    console.error('Error adding token to wallet:', error);
  }
}

// Execute
addTokenToWallet();
