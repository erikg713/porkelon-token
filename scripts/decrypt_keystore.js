// scripts/decrypt_keystore.js
const { ethers } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("Starting keystore decryption...");
  const keystorePath = process.env.KEYSTORE_PATH || path.resolve(__dirname, "../keystore/your-keystore-file.json");
  const password = process.env.KEYSTORE_PASSWORD;
  const deployments = JSON.parse(await fs.readFile(path.resolve(__dirname, "../deployments.json"), "utf8"));

  if (!password) {
    throw new Error("KEYSTORE_PASSWORD not set in .env");
  }
  if (!await fs.access(keystorePath).then(() => true).catch(() => false)) {
    throw new Error(`Keystore file not found: ${keystorePath}`);
  }

  try {
    const keystoreJson = await fs.readFile(keystorePath, "utf8");
    const wallet = await ethers.Wallet.fromEncryptedJson(keystoreJson, password);
    console.log("Wallet decrypted successfully!");
    console.log("Address:", wallet.address);

    const provider = ethers.provider;
    const connectedWallet = wallet.connect(provider);
    console.log("Connected to network:", provider._network.name);

    const balance = await provider.getBalance(wallet.address);
    console.log("POL Balance:", ethers.formatEther(balance), "POL");

    const porkelonAbi = [
      "function balanceOf(address account) view returns (uint256)",
      "function symbol() view returns (string)"
    ];
    const porkelon = new ethers.Contract(deployments.Porkelon, porkelonAbi, connectedWallet);
    const tokenSymbol = await porkelon.symbol();
    const tokenBalance = await porkelon.balanceOf(wallet.address);
    console.log(`${tokenSymbol} Balance:`, ethers.formatEther(tokenBalance));
  } catch (error) {
    console.error("Error:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => {
    console.log("Keystore decryption completed!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
