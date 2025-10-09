require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: "paris",
    },
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC || "https://rpc.ankr.com/polygon",
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: { apiKey: process.env.POLYGONSCAN_API_KEY },
};
