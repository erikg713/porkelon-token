// Modular utility for the Porkelon Presale frontend: Adds the $PORK token to MetaMask (or compatible wallets).
// Designed as reusable functions for integration into UI components or scripts.
// Supports custom token configs, network switching, and error handling.
// Usage:
// - As a script: node scripts/add_to_wallet.js (runs default add for Porkelon).
// - In frontend: Import functions into React components (e.g., button handlers).
// Dependencies: ethers (^6.13.2) - ensures browser/node compat with polyfills from vite.config.js.

// Default Porkelon Token Configuration (override via env or params)
const DEFAULT_TOKEN_CONFIG = {
  address: process.env.VITE_PORK_TOKEN_ADDRESS || '0x7f024bd81c22dafae5ecca46912acd94511210d8', // Deployed contract on Polygon
  symbol: 'PORK',
  decimals: 18,
  image: 'https://your-domain.com/porkelon-logo.png', // Optional: IPFS-hosted PNG (256x256 recommended)
};

// Polygon Mainnet Config (for auto-switch if needed)
const POLYGON_CHAIN_CONFIG = {
  chainId: '0x89', // 137 in hex
  chainName: 'Polygon Mainnet',
  nativeCurrency: { name: 'POL', symbol: 'POL', decimals: 18 },
  rpcUrls: ['https://polygon-rpc.com/'],
  blockExplorerUrls: ['https://polygonscan.com/'],
};

/**
 * Checks if the wallet provider (e.g., MetaMask) is available and connected.
 * @returns {Promise<ethers.BrowserProvider>} The provider instance.
 * @throws {Error} If no provider or connection fails.
 */
async function getWalletProvider() {
  if (typeof window === 'undefined' || !window.ethereum) {
    throw new Error('Wallet provider (e.g., MetaMask) not detected. Install or enable it.');
  }
  const provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send('eth_requestAccounts', []); // Prompt connection
  return provider;
}

/**
 * Switches the wallet to the specified Ethereum chain (e.g., Polygon).
 * @param {Object} chainConfig - Chain details (chainId, etc.).
 * @returns {Promise<void>}
 * @throws {Error} On switch failure (e.g., user reject or unsupported chain).
 */
async function switchToChain(chainConfig) {
  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: chainConfig.chainId }],
    });
  } catch (switchError) {
    // If chain not added, add it
    if (switchError.code === 4902) {
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [chainConfig],
      });
    } else {
      throw switchError;
    }
  }
}

/**
 * Adds a custom ERC-20 token to the wallet using wallet_watchAsset.
 * @param {Object} tokenConfig - Token details (address, symbol, decimals, image).
 * @returns {Promise<boolean>} True if added successfully.
 * @throws {Error} On request failure or rejection.
 */
async function addTokenToWallet(tokenConfig) {
  if (!window.ethereum) {
    throw new Error('Wallet provider not detected.');
  }

  const wasAdded = await window.ethereum.request({
    method: 'wallet_watchAsset',
    params: {
      type: 'ERC20',
      options: {
        address: tokenConfig.address,
        symbol: tokenConfig.symbol,
        decimals: tokenConfig.decimals,
        image: tokenConfig.image,
      },
    },
  });

  return wasAdded;
}

/**
 * Main handler: Optionally switch chain then add token. Modular for custom flows.
 * @param {Object} [customTokenConfig] - Override default token config.
 * @param {boolean} [autoSwitchChain=true] - Auto-switch to Polygon if true.
 * @returns {Promise<void>}
 */
async function handleAddPorkToWallet(customTokenConfig = {}, autoSwitchChain = true) {
  try {
    // Merge configs
    const tokenConfig = { ...DEFAULT_TOKEN_CONFIG, ...customTokenConfig };

    // Get provider and ensure connection
    await getWalletProvider();

    // Optional: Switch to Polygon
    if (autoSwitchChain) {
      await switchToChain(POLYGON_CHAIN_CONFIG);
    }

    // Add the token
    const success = await addTokenToWallet(tokenConfig);
    if (success) {
      console.log(`${tokenConfig.symbol} token added successfully!`);
    } else {
      console.warn('Token addition was rejected by the user.');
    }
  } catch (error) {
    console.error('Error in add-to-wallet process:', error.message || error);
  }
}

// If run as a standalone script (node), execute default flow
if (typeof require !== 'undefined' && require.main === module) {
  handleAddPorkToWallet();
}

// Export for frontend module use (e.g., in React: import { handleAddPorkToWallet } from './scripts/add_to_wallet.js';)
module.exports = {
  handleAddPorkToWallet,
  getWalletProvider,
  switchToChain,
  addTokenToWallet,
  DEFAULT_TOKEN_CONFIG,
  POLYGON_CHAIN_CONFIG,
};
