require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    polygon: {
      url: process.env.RPC_URL,           // e.g. https://polygon-rpc.com or your provider
      accounts: [process.env.PRIVATE_KEY] // 0x-prefixed private key
    },
    mumbai: {                            // optional testnet
      url: process.env.MUMBAI_RPC,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  }
};
