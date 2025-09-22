require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC,
      accounts: [process.env.PRIVATE_KEY],
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
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
