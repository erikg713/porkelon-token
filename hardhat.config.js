require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

const { PRIVATE_KEY, POLYGON_RPC, MUMBAI_RPC, POLYGONSCAN_API_KEY } = process.env;

module.exports = {
  solidity: "0.8.20",
  networks: {
    polygon: {
      url: POLYGON_RPC || "https://polygon-rpc.com",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 137,
    },
    mumbai: {
      url: MUMBAI_RPC || "https://rpc-mumbai.maticvigil.com",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 80001,
    },
  },
  etherscan: {
    apiKey: {
      polygon: POLYGONSCAN_API_KEY,
      polygonMumbai: POLYGONSCAN_API_KEY,
    },
  },
};
