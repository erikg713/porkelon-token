// add_to_wallet.js (for website/dApp integration)

import { ethers } from 'ethers';

const PORK_ADDRESS = '0x3acc6396458daAf9F0b0545a4752591880eF6e28';
const POLYGON_CHAIN_ID = 137;
const POLYGON_RPC = 'https://polygon-rpc.com';
const POLYGON_EXPLORER = 'https://polygonscan.com';
const TOKEN_SYMBOL = 'PORK';
const TOKEN_DECIMALS = 18;

// Function to add Polygon network
async function addPolygonNetwork() {
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
  } catch (error) {
    console.error('Failed to add Polygon:', error);
  }
}

// Function to add PORK token
async function addPorkToken() {
  try {
    // Ensure on Polygon
    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    if (parseInt(chainId, 16) !== POLYGON_CHAIN_ID) {
      await addPolygonNetwork();
    }

    await window.ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address: PORK_ADDRESS,
          symbol: TOKEN_SYMBOL,
          decimals: TOKEN_DECIMALS,
          image: 'https://your-token-logo-url-here.png', // Optional logo
        },
      },
    });
  } catch (error) {
    console.error('Failed to add token:', error);
  }
}

// Export or use in frontend, e.g., <button onClick={addPorkToken}>Add PORK to Wallet</button>
export { addPorkToken };
