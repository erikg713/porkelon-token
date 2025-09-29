### Porkelon-Token (PORK) ###
-------------------------
is an upgradable ERC-20 token on the Polygon network, designed as a meme/utility token with a capped supply of 100 billion tokens. It includes features like burnability, pausability, ownable control, a 1% transaction fee to a team wallet, and predefined allocations for dev, staking/rewards, liquidity, marketing, airdrops, and presale. 
The token is non-mintable after initialization to enforce the max supply.
This repository contains:
The main token smart contract (PorkelonPolygon.sol).
A presale contract (PorkelonPresale.sol).
Bash scripts for adding liquidity (scripts/add_liquidity.sh) and locking liquidity (scripts/lock_liquidity.sh).
Deployment and usage instructions.
The project emphasizes low fees on Polygon, upgradeability via UUPS proxy, and community trust through liquidity locking.
Features
Token Standard: ERC-20 (upgradeable).
Total Supply: 100,000,000,000,000,000 PORK (capped, no further minting).
Decimals: 18.
Transaction Fee: 1% on every transfer (sent to team wallet; excludes mints/burns).
Allocations:
25% Dev (team) wallet.
5% Staking and rewards.
25% Liquidity (locked for 1 year).
10% Marketing and advertising.
10% Airdrops.
25% Presale.
Security: Pausable, burnable, ownable, role-based access control.
Upgradeable: Via UUPS proxy for future enhancements (e.g., adding taxes or features).
Presale: Dedicated contract for fair token distribution.
Liquidity: Added to QuickSwap DEX and locked via Unicrypt for 1 year.
Cross-Chain Migration: Guidance for migrating from Solana (original Moonshot deployment).
Prerequisites
Wallet: MetaMask or similar, connected to Polygon mainnet (Chain ID: 137, RPC: https://polygon-rpc.com).
Funds: POL (Polygon's native token) for gas fees (~$1 total for deployment/scripts).
Tools:
Remix IDE for simple deployment.
Hardhat for advanced deployment/testing.
Foundry for scripts (install via curl -L https://foundry.paradigm.xyz | bash then foundryup).
Node.js for Hardhat.
Libraries: OpenZeppelin contracts (imported in Solidity files).
🔄 Porkelon Token Migration Plan

1. Snapshot on Solana

Freeze or mark the final supply on Solana (1B).

Take a snapshot of all Solana holders + balances (via Solscan or Solana program).

Export snapshot to CSV/JSON for migration mapping.


2. Deploy Porkelon v2 on Polygon

Deploy the PorkelonPolygon.sol contract (100B supply).

Tokenomics built in:

✅ Staking (10%) → 10B PORK

✅ Airdrops (10%) → 10B PORK

✅ Presale (10%) → 10B PORK

✅ Rewards (10%) → 10B PORK

✅ Team (20%) → 20B PORK (vesting recommended)

✅ Liquidity Lock (40%) → 40B PORK (locked 365 days)



> Allocation happens at deployment: contract mints and distributes automatically.



3. Bridge/Migration Process

Since Solana ↔ Polygon are different chains, you can’t “move” tokens directly. Instead:

Burn old Solana supply (send to dead address).

Distribute new Polygon tokens based on snapshot:

Create a claim portal (DApp) where old holders can claim new PORK by proving Solana ownership.

Alternatively, airdrop Polygon PORK directly to their mapped wallets (if you collect addresses).



4. Liquidity Lock (365 Days)

Use Unicrypt / Team Finance / Gnosis Safe to lock liquidity tokens from DEX (like QuickSwap).

Lock duration: 365 days minimum.


5. Presale + Staking + Rewards

Presale handled via a Presale contract (users send MATIC/USDT, get PORK).

Staking contract: users stake PORK to earn rewards.
Next Steps for Deployment
Prepare .env:
Copy .env.example to .env:
cp .env.example .env
Fill in real values:
PRIVATE_KEY: Your wallet’s private key (never share it).
RPC URLs: Use reliable providers (e.g., Alchemy, Infura) for POLYGON_RPC and MUMBAI_RPC.
Wallet addresses: Ensure all allocation wallets (TEAM_WALLET, etc.) are valid Ethereum addresses.
API keys: Get a POLYGONSCAN_API_KEY from Polygonscan for contract verification.
Test Locally:
Start a local Hardhat node:
npx hardhat node
Deploy to the local network:
npx hardhat run scripts/deploy.js --network hardhat
Write tests in test/ folder using Mocha/Chai to verify contract behavior.
Test on Mumbai:
Fund your deployer wallet with MATIC on Mumbai (use a faucet like https://mumbaifaucet.com).
Run:
./scripts/deploy.sh mumbai
Verify the contract on Polygonscan (Mumbai explorer).
Deploy to Polygon Mainnet:
Ensure your deployer wallet has enough MATIC for gas (check gas prices on https://polygonscan.com/gastracker).
Run:
./scripts/deploy.sh polygon
Verify the contract on Polygonscan.
Post-Deployment:
Save the contract address from deployed-address.txt.
Verify the contract on Polygonscan (if not automated in deploy.js).
If the contract is an ERC-20 token, add it to DEXs (e.g., QuickSwap) or update token metadata on CoinMarketCap (using COINMARKETCAP_API_KEY).
-----------------------------
---
------------------------------
WALLET INTEGRATION 
--------------------------
Wallet Integration
Porkelon (PORK) is an ERC-20 token on Polygon (chain ID: 137). Users can add it to wallets like MetaMask and Trust Wallet for viewing balances, sending/receiving, and interacting with dApps (e.g., staking or presale).
Manual Addition Instructions
MetaMask (Desktop/Mobile)
Open MetaMask and switch to Polygon Mainnet (if not added: Settings > Networks > Add Network; RPC: https://polygon-rpc.com, Chain ID: 137, Symbol: POL, Explorer: https://polygonscan.com).
In Assets tab, click "Import tokens".
Enter:
Token Contract Address: 0xYourDeployedPorkelonAddressHere
Token Symbol: PORK
Token Decimals: 18
Click "Add Custom Token" > "Import Tokens".
Trust Wallet (Mobile)
Open Trust Wallet app.
Search for "Polygon" and add the network if needed (similar details as above).
On the main screen, tap "+" (Add Custom Token).
Select Polygon network, paste contract address: 0xYourDeployedPorkelonAddressHere.
It auto-fills symbol (PORK) and decimals (18). Tap "Save".
Automated Addition (Website/dApp Integration)
For your project site, add buttons to trigger wallet APIs. This uses Ethereum Provider API (injected by wallets). Works for MetaMask (desktop/browser extension) and Trust Wallet (via WalletConnect or in-app browser).
