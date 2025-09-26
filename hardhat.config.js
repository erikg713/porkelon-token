require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();  // yarn add dotenv

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: { optimizer: { enabled: true, runs: 200 } }
  },
  networks: {
    mumbai: {
      url: process.env.MUMBAI_RPC_URL || "https://polygon-mumbai.g.alchemy.com/v2/YOUR_KEY",
      accounts: [process.env.PRIVATE_KEY],  // Your deployer wallet priv key (never commit!)
      chainId: 80001
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137
    }
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY  // For verification
  }
};

require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

const { ethers, upgrades } = require("hardhat");

async function main() {
  const PorkelonPolygon = await ethers.getContractFactory("PorkelonPolygon");
  const porkelon = await upgrades.deployProxy(PorkelonPolygon, ["0xYourDevWalletHere", "0xYourLiquidityWalletHere"], { initializer: 'initialize', kind: 'uups' });
  console.log("Porkelon deployed to:", await porkelon.getAddress());
}

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
 main },
