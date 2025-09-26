// generate_hd_wallets.js
// Generates Hierarchical Deterministic (HD) wallets from a BIP39 mnemonic for the Porkelon project.
// Usage: node generate_hd_wallets.js [num_wallets] [network]
//   num_wallets: Number of wallets to generate (default: 10)
//   network: 'polygon' or 'amoy' (default: 'polygon')
// This script uses ethers.js to derive child wallets from a master mnemonic.
// WARNING: The mnemonic and private keys are sensitive. Run locally and never commit to version control.
// Import the generated wallets into MetaMask for team payments or testing.

const { ethers } = require("ethers");
const fs = require("fs").promises;
const path = require("path");

async function main() {
  const args = process.argv.slice(2);
  const numWallets = parseInt(args[0]) || 10;
  const network = args[1] || "polygon";

  if (numWallets < 1 || numWallets > 100) {
    console.error("Error: num_wallets must be between 1 and 100.");
    process.exit(1);
  }

  // Generate or load mnemonic (in production, use a secure entropy source)
  let mnemonic;
  const mnemonicPath = path.resolve(__dirname, "../.mnemonic.txt");
  try {
    mnemonic = await fs.readFile(mnemonicPath, "utf8").then(m => m.trim());
    console.log("Using existing mnemonic from .mnemonic.txt");
  } catch (error) {
    mnemonic = ethers.Wallet.createRandom().mnemonic.phrase;
    await fs.writeFile(mnemonicPath, mnemonic);
    console.log("Generated new mnemonic and saved to .mnemonic.txt");
  }

  console.log("Mnemonic (BACKUP THIS!):", mnemonic);

  // Create HD node
  const hdNode = ethers.utils.HDNodeWallet.fromMnemonic(mnemonic);

  // Network config for address derivation
  const chainId = network === "amoy" ? 80002 : 137;
  const chainName = network === "amoy" ? "Amoy Testnet" : "Polygon Mainnet";
  console.log(`Generating ${numWallets} HD wallets for ${chainName} (Chain ID: ${chainId})...`);

  const wallets = [];
  for (let i = 0; i < numWallets; i++) {
    const wallet = hdNode.derivePath(`m/44'/60'/0'/0/${i}`);
    const address = wallet.address;
    const privateKey = wallet.privateKey;

    wallets.push({
      index: i,
      derivationPath: `m/44'/60'/0'/0/${i}`,
      address,
      privateKey, // WARNING: Sensitive - use for local testing only
      mnemonic // Included for convenience, but back it up separately
    });

    console.log(`Wallet ${i}:`);
    console.log(`  Address: ${address}`);
    console.log(`  Private Key: ${privateKey}`);
    console.log(`  Derivation Path: ${wallets[i].derivationPath}`);
    console.log("");
  }

  // Save to JSON file
  const outputPath = path.resolve(__dirname, `../hd_wallets_${network}.json`);
  await fs.writeFile(outputPath, JSON.stringify(wallets, null, 2));
  console.log(`Generated ${numWallets} wallets saved to: ${outputPath}`);

  // Security reminder
  console.log("\n⚠️  SECURITY WARNING:");
  console.log("1. BACKUP your mnemonic immediately and store it offline.");
  console.log("2. Never share private keys or mnemonic.");
  console.log("3. For team payments, import addresses into MetaMask (do not import private keys on shared devices).");
  console.log("4. Add .mnemonic.txt and hd_wallets_*.json to .gitignore.");
  console.log("5. For production, generate mnemonic securely (e.g., via hardware wallet or offline tool).");
}

main()
  .catch((error) => {
    console.error("Error generating HD wallets:", error);
    process.exit(1);
  });
