// generate_independent_wallets.js
// Generates N independent ETH wallets, writes encrypted keystore JSON and a CSV mapping.
// Usage: node generate_independent_wallets.js <count> <passwordForKeystores> [solana_map.csv]
// Example: node generate_independent_wallets.js 100 "StrongPass!234" sol_to_map.csv

import fs from 'fs';
import path from 'path';
import { ethers } from 'ethers';
import { parse } from 'csv-parse/sync';
import { stringify } from 'csv-stringify/sync';

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node generate_independent_wallets.js <count> <keystorePassword> [solana_map.csv]');
    process.exit(1);
  }
  const count = parseInt(args[0], 10);
  const keystorePassword = args[1];
  const solanaCsvPath = args[2] || null;

  const outDir = path.resolve(process.cwd(), 'keystores_independent');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  // load Solana address list if provided (CSV with a single column "solana_address")
  let solList = [];
  if (solanaCsvPath) {
    const raw = fs.readFileSync(solanaCsvPath, 'utf8');
    const records = parse(raw, { columns: true, skip_empty_lines: true });
    solList = records.map(r => r.solana_address || Object.values(r)[0]);
    if (solList.length < count) {
      console.warn('WARNING: provided Solana list size < wallet count; remaining wallets will have empty mapping.');
    }
  }

  const csvRows = [];
  for (let i = 0; i < count; i++) {
    const wallet = ethers.Wallet.createRandom();
    const address = wallet.address;
    const priv = wallet.privateKey; // keep offline; we will not print to console except optionally

    // encrypt keystore JSON
    const keystoreFileName = `keystore_${address.replace('0x','')}.json`;
    console.log(`Creating wallet ${i+1}/${count}: ${address}`);
    const json = await wallet.encrypt(keystorePassword, { scrypt: { N: 1<<18 } }); // scrypt params may be heavy; adjust if needed
    fs.writeFileSync(path.join(outDir, keystoreFileName), json, { encoding: 'utf8', mode: 0o600 });

    // Add mapping row (solana_address, eth_address, keystore_file)
    const sol = solList[i] || '';
    csvRows.push({ solana_address: sol, eth_address: address, keystore_file: keystoreFileName });

    // Optionally also save private key to a local file encrypted by your password — but be careful.
    // Here we avoid saving raw priv keys. If you want them, uncomment carefully.
    // fs.writeFileSync(path.join(outDir, `priv_${address.replace('0x','')}.txt`), priv, { encoding: 'utf8', mode: 0o600 });
  }

  const csvOut = stringify(csvRows, { header: true, columns: ['solana_address','eth_address','keystore_file'] });
  fs.writeFileSync(path.join(outDir, 'mapping.csv'), csvOut, { encoding: 'utf8', mode: 0o600 });

  console.log('Done. Keystore JSON files and mapping.csv written to:', outDir);
  console.log('IMPORTANT: Keystore password is the one you provided. Do NOT share password or files.');
}

main().catch(err => { console.error(err); process.exit(1); });
