// decrypt_keystore.js
// Decrypt an encrypted keystore JSON (created by ethers Wallet.encrypt) locally and print the private key.
// Usage: node decrypt_keystore.js <keystore.json> <password>
// WARNING: This prints the raw private key to stdout. Do NOT run on an untrusted machine or paste the key to any online service.

import fs from 'fs';
import { ethers } from 'ethers';

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node decrypt_keystore.js <keystore.json> <password>');
    process.exit(1);
  }
  const pathToKeystore = args[0];
  const password = args[1];

  if (!fs.existsSync(pathToKeystore)) {
    console.error('Error: keystore file not found:', pathToKeystore);
    process.exit(1);
  }

  const raw = fs.readFileSync(pathToKeystore, 'utf8');
  const wallet = await ethers.Wallet.fromEncryptedJson(raw, password);
  console.log('ADDRESS:', wallet.address);
  console.log('PRIVATE_KEY:', wallet.privateKey); // copy this locally and import to MetaMask > Import account
}

main().catch(e => { console.error(e); process.exit(1); });
