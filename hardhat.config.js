require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { POLYGON_RPC, MUMBAI_RPC, PRIVATE_KEY, POLYGONSCAN_API_KEY } = process.env;
const accounts = PRIVATE_KEY ? [PRIVATE_KEY] : [];

module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.20",
    settings: { optimizer: { enabled: true, runs: 200 }, metadata: { bytecodeHash: "ipfs" }, viaIR: true },
  },
  networks: {
    hardhat: { chainId: 1337 },
    mumbai: { url: MUMBAI_RPC || "https://rpc-mumbai.maticvigil.com", accounts, chainId: 80001 },
    polygon: { url: POLYGON_RPC || "https://polygon-rpc.com", accounts, chainId: 137 },
  },
  etherscan: {
    apiKey: POLYGONSCAN_API_KEY || "",
  },
};
