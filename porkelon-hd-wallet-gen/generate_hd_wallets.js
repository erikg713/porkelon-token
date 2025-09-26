// porkelon-hd-wallet-gen/generate_hd_wallets.js
const { ethers } = require("ethers");
const fs = require("fs").promises;
const path = require("path");
require("dotenv").config();

async function main() {
  const args = process.argv.slice(2);
  const numWallets = parseInt(args[0]) || 1;
  const network = args[1] || "polygon";

  if (numWallets < 1 || numWallets > 100) {
    console.error("Error: num_wallets must be between 1 and 100.");
    process.exit(1);
  }

  // Check existing wallets in .env
  const existingWallets = [
    process.env.TEAM_WALLET,
    process.env.PRESALE_WALLET,
    process.env.AIRDROP_WALLET,
    process.env.STAKING_WALLET,
    process.env.REWARDS_WALLET,
    process.env.MARKETING_WALLET,
    process.env.LIQUIDITY_WALLET,
    process.env.FUNDS_WALLET
  ].filter(w => w && ethers.isAddress(w));
  console.log("Existing wallets in .env:", existingWallets);

  // Generate or load mnemonic
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

  // Network config
  const chainId = network === "amoy" ? 80002 : 137;
  const chainName = network === "amoy" ? "Amoy Testnet" : "Polygon Mainnet";
  console.log(`Generating ${numWallets} HD wallets for ${chainName} (Chain ID: ${chainId})...`);

  const wallets = [];
  let startIndex = 0;
  try {
    const existingWalletsFile = await fs.readFile(path.resolve(__dirname, `../hd_wallets_${network}.json`), "utf8");
    const existing = JSON.parse(existingWalletsFile);
    startIndex = existing.length;
  } catch (error) {
    console.log("No existing hd_wallets file, starting from index 0.");
  }

  for (let i = startIndex; i < startIndex + numWallets; i++) {
    const wallet = hdNode.derivePath(`m/44'/60'/0'/0/${i}`);
    const address = wallet.address;
    if (existingWallets.includes(address)) {
      console.warn(`Wallet ${i} (${address}) already in .env, skipping.`);
      continue;
    }
    wallets.push({
      index: i,
      derivationPath: `m/44'/60'/0'/0/${i}`,
      address,
      privateKey: wallet.privateKey,
      mnemonic
    });
    console.log(`Wallet ${i}:`);
    console.log(`  Address: ${address}`);
    console.log(`  Private Key: ${wallet.privateKey}`);
    console.log(`  Derivation Path: m/44'/60'/0'/0/${i}`);
    console.log("");
  }

  // Save to JSON file
  const outputPath = path.resolve(__dirname, `../hd_wallets_${network}.json`);
  let existingWalletsData = [];
  try {
    existingWalletsData = JSON.parse(await fs.readFile(outputPath, "utf8"));
  } catch (error) {
    // File doesn't exist, proceed with empty array
  }
  const updatedWallets = [...existingWalletsData, ...wallets];
  await fs.writeFile(outputPath, JSON.stringify(updatedWallets, null, 2));
  console.log(`Generated/updated ${wallets.length} wallets saved to: ${outputPath}`);

  // Suggest .env update for MARKETING_WALLET
  if (!process.env.MARKETING_WALLET || process.env.MARKETING_WALLET === "0xYourMarketingWalletHere") {
    console.log("\nSuggested .env update for MARKETING_WALLET:");
    console.log(`MARKETING_WALLET=${wallets[0]?.address || "0xGenerateNewWallet"}`);
  }

  // Security reminder
  console.log("\n⚠️  SECURITY WARNING:");
  console.log("1. BACKUP your mnemonic immediately and store it offline.");
  console.log("2. Never share private keys or mnemonic.");
  console.log("3. For team payments, import addresses into MetaMask (do not import private keys on shared devices).");
  console.log("4. Ensure .mnemonic.txt and hd_wallets_*.json are in .gitignore.");
  console.log("5. For production, generate mnemonic securely (e.g., via hardware wallet).");
}

main()
  .catch((error) => {
    console.error("Error generating HD wallets:", error);
    process.exit(1);
  });
