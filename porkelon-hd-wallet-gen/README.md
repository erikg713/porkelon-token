# Porkelon HD Wallet Generator (Option B)

This package provides scripts to **generate a single HD mnemonic** and derive many Ethereum/Polygon addresses (MetaMask-compatible). Use this when migrating users/tokens from Solana to Polygon and you want deterministic derived addresses (one mnemonic controls multiple addresses).

IMPORTANT: **Run these scripts locally on a secure machine**. Do NOT run on shared/online services. Back up the mnemonic offline (paper/metal).

## What's included
- `generate_hd_wallets.js` — generate a 24-word mnemonic and N derived addresses, save encrypted keystores and a CSV mapping.
- `decrypt_keystore.js` — decrypt a keystore JSON locally to reveal the private key (use only on secure machines).
- `package.json` — dependencies and helper script.
- `README.md` — this file.

## Prerequisites
- Node.js >=16 (recommended >=18)
- npm
- Run locally (not in cloud)

## Install
```bash
mkdir porkelon-hd-wallets && cd porkelon-hd-wallets
# copy files here or unzip the provided archive
npm install
