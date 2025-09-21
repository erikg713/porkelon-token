// generate_monad_test_wallet.js
// Run: node generate_monad_test_wallet.js <keystorePassword (optional)>
// Example: node generate_monad_test_wallet.js "MySafeTestPass!"
// Output: prints address and private key (use only on testnet); writes keystore json if password provided.

import fs from "fs";
import path from "path";
import { Wallet } from "ethers";
import { Wallet } from "ethers";

// Generate new wallet
const wallet = Wallet.createRandom();

console.log("=== MONAD TESTNET WALLET ===");
console.log("Address:", wallet.address);
console.log("Private Key:", wallet.privateKey);
console.log("Mnemonic:", wallet.mnemonic.phrase);
async function main() {
  const password = process.argv[2] || null;
  const wallet = Wallet.createRandom(); // secure RNG from node crypto
  console.log("=== MONAD TESTNET WALLET (TEST ONLY) ===");
  console.log("Address:", wallet.address);
  console.log("Private Key (0x...):", wallet.privateKey);
  console.log("---- IMPORTANT: do NOT use this private key on mainnet or for real funds. ----");

  if (password) {
    const outDir = path.resolve(process.cwd(), "monad_keystore");
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
    const json = await wallet.encrypt(password);
    const fname = `keystore_${wallet.address.replace("0x","")}.json`;
    fs.writeFileSync(path.join(outDir, fname), json, { encoding: "utf8", mode: 0o600 });
    console.log("Encrypted keystore written to:", path.join(outDir, fname));
  }
}

main().catch(e => { console.error(e); process.exit(1); });
