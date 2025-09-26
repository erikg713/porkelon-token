// scripts/decrypt_keystore.js
// Decrypts an Ethereum keystore JSON file to retrieve private key/address for Porkelon deployment or interaction.
// Usage: npx hardhat run scripts/decrypt_keystore.js --network amoy
// WARNING: Outputs private key to console. Run ONLY on a trusted machine. Never share or commit the key.

const { ethers } = require("hardhat");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  // Configuration
  const keystorePath = path.resolve(__dirname, "../keystore/your-keystore-file.json"); // Replace with your keystore file path
  const password = process.env.KEYSTORE_PASSWORD; // Store in .env
  const porkelonAddress = "0x3acc6396458daAf9F0b0545a4752591880eF6e28"; // Replace with your deployed Porkelon address

  // Validate inputs
  if (!password) {
    console.error("Error: KEYSTORE_PASSWORD not set in .env");
    process.exit(1);
  }
  if (!fs.existsSync(keystorePath)) {
    console.error("Error: Keystore file not found:", keystorePath);
    process.exit(1);
  }

  try {
    // Read and decrypt keystore
    const keystoreJson = await fs.readFile(keystorePath, "utf8");
    const wallet = await ethers.Wallet.fromEncryptedJson(keystoreJson, password);
    console.log("Wallet decrypted successfully!");
    console.log("ADDRESS:", wallet.address);
    console.log("PRIVATE_KEY:", wallet.privateKey); // WARNING: Keep secure!

    // Connect to Polygon/Amoy provider
    const provider = ethers.provider; // Hardhat provides this based on --network
    const connectedWallet = wallet.connect(provider);
    console.log("Wallet connected to provider:", provider._network.name);

    // Check POL balance
    const balance = await provider.getBalance(wallet.address);
    console.log("POL Balance:", ethers.formatEther(balance), "POL");

    // Interact with Porkelon contract
    const porkelonAbi = [
      "function balanceOf(address account) view returns (uint256)",
      "function transfer(address to, uint256 amount) returns (bool)",
      "function symbol() view returns (string)"
    ];
    const porkelon = new ethers.Contract(porkelonAddress, porkelonAbi, connectedWallet);
    const tokenSymbol = await porkelon.symbol();
    const tokenBalance = await porkelon.balanceOf(wallet.address);
    console.log(`${tokenSymbol} Balance:`, ethers.formatEther(tokenBalance));

    // Optional: Example transfer (uncomment to use)
    /*
    const recipient = "0xYourRecipientAddressHere"; // Replace
    const amount = ethers.parseEther("100"); // 100 PORK
    const tx = await porkelon.transfer(recipient, amount);
    console.log("Transfer transaction sent:", tx.hash);
    await tx.wait();
    console.log("Transfer confirmed!");
    */

  } catch (error) {
    console.error("Error decrypting keystore or interacting with contract:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
