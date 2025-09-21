Overview
Porkelon (PORK) is an upgradable ERC-20 token on the Polygon network, designed as a meme/utility token with a capped supply of 100 billion tokens. It includes features like burnability, pausability, ownable control, a 1% transaction fee to a team wallet, and predefined allocations for dev, staking/rewards, liquidity, marketing, airdrops, and presale. The token is non-mintable after initialization to enforce the max supply.
This repository contains:
The main token smart contract (Porkelon.sol).
A presale contract (PorkelonPresale.sol).
Bash scripts for adding liquidity (scripts/add_liquidity.sh) and locking liquidity (scripts/lock_liquidity.sh).
Deployment and usage instructions.
The project emphasizes low fees on Polygon, upgradeability via UUPS proxy, and community trust through liquidity locking.
Features
Token Standard: ERC-20 (upgradeable).
Total Supply: 100,000,000,000 PORK (capped, no further minting).
Decimals: 18.
Transaction Fee: 1% on every transfer (sent to team wallet; excludes mints/burns).
Allocations:
20% Dev wallet.
5% Staking and rewards.
25% Liquidity (locked for 1 year).
10% Marketing and advertising.
10% Airdrops.
30% Presale.
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
