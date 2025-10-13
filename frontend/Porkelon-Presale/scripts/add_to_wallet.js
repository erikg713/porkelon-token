import { ethers } from 'ethers';

const CONFIG = {
  PORK_ADDRESS: process.env.REACT_APP_PORK_ADDRESS || '0xYourPorkelonAddressHere',
  POLYGON_CHAIN_ID: 137,
  POLYGON_RPC: 'https://polygon-rpc.com/',
  POLYGON_EXPLORER: 'https://polygonscan.com',
  TOKEN_SYMBOL: 'PORK',
  TOKEN_DECIMALS: 18,
  TOKEN_IMAGE: 'https://your-token-logo-url-here.png'
};

async function switchToPolygon() {
  if (!window.ethereum) {
    throw new Error('No Ethereum wallet detected. Please install MetaMask.');
  }

  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: ethers.utils.hexValue(CONFIG.POLYGON_CHAIN_ID) }],
    });
    return true;
  } catch (switchError) {
    if (switchError.code === 4902) {
      try {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: ethers.utils.hexValue(CONFIG.POLYGON_CHAIN_ID),
            chainName: 'Polygon Mainnet',
            nativeCurrency: { name: 'POL', symbol: 'POL', decimals: 18 },
            rpcUrls: [CONFIG.POLYGON_RPC],
            blockExplorerUrls: [CONFIG.POLYGON_EXPLORER],
          }],
        });
        await window.ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: ethers.utils.hexValue(CONFIG.POLYGON_CHAIN_ID) }],
        });
        return true;
      } catch (addError) {
        throw new Error(`Failed to add Polygon network: ${addError.message}`);
      }
    }
    throw new Error(`Failed to switch to Polygon: ${switchError.message}`);
  }
}

async function addPorkToken() {
  try {
    if (!window.ethereum) {
      throw new Error('No Ethereum wallet detected. Please install MetaMask.');
    }

    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    if (parseInt(chainId, 16) !== CONFIG.POLYGON_CHAIN_ID) {
      await switchToPolygon();
    }

    const wasAdded = await window.ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address: CONFIG.PORK_ADDRESS,
          symbol: CONFIG.TOKEN_SYMBOL,
          decimals: CONFIG.TOKEN_DECIMALS,
          image: CONFIG.TOKEN_IMAGE,
        },
      },
    });

    return wasAdded ? 'PORK token added successfully!' : 'User rejected adding the token.';
  } catch (error) {
    throw new Error(`Failed to add token: ${error.message}`);
  }
}

export { addPorkToken };
