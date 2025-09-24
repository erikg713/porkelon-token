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
