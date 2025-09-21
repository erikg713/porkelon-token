// generate_hd_wallets.js
// Generates one mnemonic and derives multiple accounts using standard derivation path m/44'/60'/0'/0/index
// Writes mnemonic (WARNING: store offline) encrypted keystore for each derived account, and outputs a CSV of derived addresses.
// Usage: node generate_hd_wallets.js <count> <keystorePassword> [solana_map.csv]
// Example: node generate_hd_wallets.js 200 "YourStrongKeystorePassword!" sol_to_map.csv

import fs from 'fs';
import path from 'path';
import bip39 from 'bip39';
import { ethers } from 'ethers';
import { parse } from 'csv-parse/sync';
import { stringify } from 'csv-stringify/sync';

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node generate_hd_wallets.js <count> <keystorePassword> [solana_map.csv]');
    process.exit(1);
  }
  const count = parseInt(args[0], 10);
  const keystorePassword = args[1];
  const solanaCsvPath = args[2] || null;

  if (Number.isNaN(count) || count <= 0) {
    console.error('Error: <count> must be a positive integer.');
    process.exit(1);
  }

  const outDir = path.resolve(process.cwd(), 'keystores_hd');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  // Generate mnemonic (24 words)
  const mnemonic = bip39.generateMnemonic(256); // 24 words
  console.log('*** IMPORTANT — BACKUP THIS MNEMONIC OFFLINE IMMEDIATELY ***');
  console.log(mnemonic);

  // Save mnemonic to a file in the output directory (RECOMMENDED: move this file offline immediately)
  const mnemonicFile = path.join(outDir, 'mnemonic_backup.txt');
  fs.writeFileSync(mnemonicFile, `MNEMONIC (store offline):\n${mnemonic}\n\nDO NOT SHARE\n`, { encoding: 'utf8', mode: 0o600 });

  // load Solana addresses if provided (CSV with column solana_address or single-column)
  let solList = [];
  if (solanaCsvPath) {
    const raw = fs.readFileSync(solanaCsvPath, 'utf8');
    // try to parse with header; if no header, csv-parse will still return rows
    const records = parse(raw, { columns: true, skip_empty_lines: true });
    solList = records.map(r => r.solana_address || Object.values(r)[0]);
  }

  const csvRows = [];

  // Create HD node from mnemonic
  // ethers.utils.HDNode is available in ethers v6 under ethers.utils.HDNode
  const hdNode = ethers.utils.HDNode.fromMnemonic(mnemonic);

  for (let i = 0; i < count; i++) {
    // standard MetaMask derivation path: m/44'/60'/0'/0/i
    const child = hdNode.derivePath(`m/44'/60'/0'/0/${i}`);
    const address = child.address;
    const wallet = new ethers.Wallet(child.privateKey);
    const keystoreFileName = `hd_keystore_${i}_${address.replace('0x','')}.json`;

    // Encrypt each derived private key with the provided keystore password.
    // Use default encryption parameters; you can tune scrypt options for stronger/longer encryption.
    const json = await wallet.encrypt(keystorePassword);
    fs.writeFileSync(path.join(outDir, keystoreFileName), json, { encoding: 'utf8', mode: 0o600 });

    const sol = solList[i] || '';
    csvRows.push({ index: i, solana_address: sol, eth_address: address, keystore_file: keystoreFileName });
    console.log(`Derived ${i}: ${address}`);
  }

  const csvOut = stringify(csvRows, { header: true, columns: ['index','solana_address','eth_address','keystore_file'] });
  fs.writeFileSync(path.join(outDir, 'mapping_hd.csv'), csvOut, { encoding: 'utf8', mode: 0o600 });

  console.log('Done. HD keystore files and mapping_hd.csv written to:', outDir);
  console.log('Mnemonic saved to:', mnemonicFile, ' — MOVE IT OFF THIS MACHINE TO A SAFE, OFFLINE LOCATION NOW.');
}

main().catch(err => { console.error(err); process.exit(1); });
