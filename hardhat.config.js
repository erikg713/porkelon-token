require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const {
  PRIVATE_KEY,
  POLYGON_RPC = "https://polygon-rpc.com",
  MUMBAI_RPC = "https://rpc-mumbai.maticvigil.com",
  POLYGONSCAN_API_KEY,
  ETHERSCAN_API_KEY,
  REPORT_GAS = "true",
  COINMARKETCAP_API_KEY
} = process.env;

// Parse private keys with fallback to a dummy key for local testing
const privateKeys = PRIVATE_KEY ? PRIVATE_KEY.split(",").map(k => k.trim()) : ["0x0000000000000000000000000000000000000000000000000000000000000000"];

const networks = {
  hardhat: {
    chainId: 1337,
    forking: { enabled: false } // Enable for mainnet forking if needed
  },
  mumbai: {
    url: MUMBAI_RPC,
    accounts: privateKeys,
    chainId: 80001
  },
  polygon: {
    url: POLYGON_RPC,
    accounts: privateKeys,
    chainId: 137
  }
};

const etherscanApiKeys = {};
if (ETHERSCAN_API_KEY) {
  etherscanApiKeys.mainnet = ETHERSCAN_API_KEY;
  etherscanApiKeys.sepolia = ETHERSCAN_API_KEY;
}
if (POLYGONSCAN_API_KEY) {
  etherscanApiKeys.polygon = POLYGONSCAN_API_KEY;
  etherscanApiKeys.polygonMumbai = POLYGONSCAN_API_KEY;
}

module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      metadata: { bytecodeHash: "ipfs" },
      viaIR: true
    }
  },
  networks,
  etherscan: {
    apiKey: etherscanApiKeys
  },
  gasReporter: {
    enabled: REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: COINMARKETCAP_API_KEY || undefined,
    noColors: true
  },
  mocha: { timeout: 200_000 }
};
