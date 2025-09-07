/**
 * Hardhat configuration
 *
 * Clean, explicit, and resilient configuration that:
 * - Enables optimizer for production-like builds
 * - Normalizes private key inputs safely (supports comma-separated keys)
 * - Conditionally enables networks from env vars (no accidental overruns)
 * - Provides friendly defaults for mocha and compiler settings
 *
 * Notes:
 * - Keep secrets out of source control. Use a .env file or CI secrets.
 * - If you want gas reporting or hardhat-deploy features, install those plugins
 *   (hardhat-gas-reporter, hardhat-deploy) and enable them via environment variables.
 */

require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

const {
  PRIVATE_KEY = "",
  SEPOLIA_RPC = "",
  MAINNET_RPC = "",
  POLYGON_RPC = "",
  ETHERSCAN_API_KEY = "",
  POLYGONSCAN_API_KEY = "",
  COINMARKETCAP_API_KEY = "",
  REPORT_GAS = "false"
} = process.env;

/**
 * Safely parse private key(s) from env var.
 * Accepts:
 * - single key: "0xabc..."
 * - multiple keys: "0xaaa...,0xbbb..."
 * - without 0x prefix: "aaa,bbb" -> will be normalized
 *
 * Returns an array suitable for Hardhat's `accounts` field.
 */
function parsePrivateKeys(raw) {
  if (!raw || typeof raw !== "string") return [];
  return raw
    .split(",")
    .map(k => k.trim())
    .filter(Boolean)
    .map(k => (k.startsWith("0x") ? k : `0x${k}`));
}

const privateKeys = parsePrivateKeys(PRIVATE_KEY);

const networks = {
  hardhat: {
    chainId: 1337,
    // keep the default network fast and deterministic for local testing
    allowUnlimitedContractSize: false
  }
};

// Add named public networks only when RPC URL is provided to avoid accidental use.
if (SEPOLIA_RPC) {
  networks.sepolia = {
    url: SEPOLIA_RPC,
    accounts: privateKeys,
    chainId: 11155111
  };
}

if (MAINNET_RPC) {
  networks.mainnet = {
    url: MAINNET_RPC,
    accounts: privateKeys,
    chainId: 1
  };
}

if (POLYGON_RPC) {
  networks.polygon = {
    url: POLYGON_RPC,
    accounts: privateKeys,
    chainId: 137
  };
}

// Etherscan config supports multiple networks via an object.
// Keep values empty when keys are not set to avoid accidental leakage.
const etherscanApiKey = {};
if (ETHERSCAN_API_KEY) etherscanApiKey.mainnet = ETHERSCAN_API_KEY;
if (ETHERSCAN_API_KEY) etherscanApiKey.sepolia = ETHERSCAN_API_KEY;
if (POLYGONSCAN_API_KEY) etherscanApiKey.polygon = POLYGONSCAN_API_KEY;

module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.20",
    settings: {
      // Optimizer on for smaller and faster bytecode in production-like builds
      optimizer: {
        enabled: true,
        runs: 200
      },
      // Use IPFS metadata hash to make bytecode determinism slightly better across toolchains
      metadata: {
        bytecodeHash: "ipfs"
      },
      // viaIR may improve gas in some cases for newer compilers; recommended for 0.8.20+
      viaIR: true
    }
  },
  networks,
  etherscan: {
    apiKey: Object.keys(etherscanApiKey).length ? etherscanApiKey : ETHERSCAN_API_KEY || ""
  },
  // Optional gas reporter configuration - only effective if plugin installed and REPORT_GAS=true
  gasReporter: {
    enabled: REPORT_GAS === "true",
    currency: "USD",
    // Provide a CoinMarketCap key in env if you want currency conversion
    coinmarketcap: COINMARKETCAP_API_KEY || undefined,
    // reduce noise in CI logs by default
    noColors: true
  },
  mocha: {
    // Increased timeout to account for network interactions during integration tests
    timeout: 200_000
  },
  // Expose the parsed keys so scripts can reuse them without reparsing env values.
  _parsedPrivateKeys: privateKeys
};
