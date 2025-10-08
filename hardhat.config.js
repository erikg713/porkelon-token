require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

module.exports = {
  solidity: "0.8.24",
  networks: {
    polygon: {
      url: "https://rpc.ankr.com/polygon", // or your Infura key if preferred
      accounts: [process.env.PRIVATE_KEY], // private key of deployer
      gasPrice: "auto",
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY, // optional: for verification
  },
};
