// decrypt_keystore.js
import fs from 'fs';
import { ethers } from 'ethers';

async function main() {
  const pathToKeystore = process.argv[2];
  const password = process.argv[3];
  if (!pathToKeystore || !password) {
    console.error('Usage: node decrypt_keystore.js <keystore.json> <password>');
    process.exit(1);
  }
  const raw = fs.readFileSync(pathToKeystore, 'utf8');
  const wallet = await ethers.Wallet.fromEncryptedJson(raw, password);
  console.log('ADDRESS:', wallet.address);
  console.log('PRIVATE_KEY:', wallet.privateKey); // copy this locally and import to MetaMask > Import account
}
main().catch(e => console.error(e));
