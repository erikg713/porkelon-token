// add_to_wallet.js (for website/dApp integration)

import { ethers } from 'ethers';

const PORK_ADDRESS = '0x3acc6396458daAf9F0b0545a4752591880eF6e28';  // Replace with your actual deployed token address
const POLYGON_CHAIN_ID = 137;
const POLYGON_RPC = 'https://polygon-rpc.com';  // Consider using a personal RPC like Alchemy for production to avoid rate limits
const POLYGON_EXPLORER = 'https://polygonscan.com';
const TOKEN_SYMBOL = 'PORK';
const TOKEN_DECIMALS = 18;
const TOKEN_IMAGE = 'https://your-token-logo-url-here.png';  // Replace with your actual token logo URL (optional but recommended)

// Function to switch to Polygon network (adds if not present)
async function switchToPolygon() {
  if (!window.ethereum) {
    console.error('No Ethereum wallet detected');
    return false;
  }

  try {
    // Try to switch first
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: ethers.utils.hexValue(POLYGON_CHAIN_ID) }],
    });
    return true;
  } catch (switchError) {
    // Error code 4902 means chain not added
    if (switchError.code === 4902) {
      try {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: ethers.utils.hexValue(POLYGON_CHAIN_ID),
            chainName: 'Polygon Mainnet',
            nativeCurrency: { name: 'POL', symbol: 'POL', decimals: 18 },
            rpcUrls: [POLYGON_RPC],
            blockExplorerUrls: [POLYGON_EXPLORER],
          }],
        });
        // Switch after adding
        await window.ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: ethers.utils.hexValue(POLYGON_CHAIN_ID) }],
        });
        return true;
      } catch (addError) {
        console.error('Failed to add Polygon network:', addError);
        return false;
      }
    } else {
      console.error('Failed to switch to Polygon:', switchError);
      return false;
    }
  }
}

// Function to add PORK token to wallet
async function addPorkToken() {
  if (!window.ethereum) {
    console.error('No Ethereum wallet detected');
    return;
  }

  try {
    // Ensure on Polygon chain
    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    if (parseInt(chainId, 16) !== POLYGON_CHAIN_ID) {
      const switched = await switchToPolygon();
      if (!switched) {
        throw new Error('Failed to switch to Polygon network');
      }
    }

    // Add the token
    const wasAdded = await window.ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address: PORK_ADDRESS,
          symbol: TOKEN_SYMBOL,
          decimals: TOKEN_DECIMALS,
          image: TOKEN_IMAGE,
        },
      },
    });

    if (wasAdded) {
      console.log('PORK token added successfully!');
    } else {
      console.log('User rejected adding the token.');
    }
  } catch (error) {
    console.error('Failed to add token:', error);
  }
}

// Export for use in frontend, e.g., <button onClick={addPorkToken}>Add PORK to Wallet</button>
export { addPorkToken };
