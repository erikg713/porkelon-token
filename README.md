# 🐖 Porkelon Token (PORK)

Porkelon Token (PORK) is a simple, lightweight deflationary ERC-20 built for the Ethereum Sepolia testnet. It implements a 1% marketing fee on transfers and includes standard ERC-20 features (mint, burn, transfer) with Ownable access control.

Quick facts
- Ticker: **PORK**
- Total supply: **60,000,000,000 PORK** (18 decimals)
- Fee: **1%** of every transfer is forwarded to the configured marketing wallet
- Network used in this repo: **Ethereum Sepolia Testnet**
- Features: Ownable, Mintable, Burnable, Transferable

Table of contents
- Requirements
- Setup
- Compile
- Tests
- Deploy
- Verify on Etherscan
- Interacting with the contract
- Environment variables
- Security & notes
- Contributing & license

Requirements
- Node.js (v16+ recommended)
- npm or yarn
- An Ethereum RPC URL for Sepolia (Infura, Alchemy, or other)
- A funded Sepolia account private key (for deployment)
- ETHERSCAN API key (for verification, if you want to verify on Etherscan)

Setup

1. Clone the repo and install dependencies
```bash
git clone https://github.com/erikg713/porkelon-token.git
cd porkelon-token
npm install
# or
# yarn
```

2. Copy the example environment file and fill in the required values
```bash
cp .env.example .env
```
Open `.env` and set:
- PRIVATE_KEY — deployer account private key (never commit this)
- SEPOLIA_RPC_URL — Sepolia JSON-RPC endpoint (Infura/Alchemy)
- MARKETING_WALLET — address that will receive the 1% fees
- ETHERSCAN_API_KEY — (optional) for contract verification

(If a `.env.example` file is not present, create a `.env` with the keys above.)

Compile
```bash
npx hardhat compile
```

Tests
Unit tests are included and runnable with:
```bash
npm test
# or
npx hardhat test
```
Tests run on Hardhat's in-memory network by default. They validate token behavior, fee routing, mint/burn, and access control.

Deploy (Sepolia)
There are convenience npm scripts. The deploy script reads your `.env` to get the deployer key, RPC URL and marketing wallet.

Example:
```bash
# builds and deploys to Sepolia using the configured deploy script
npm run deploy:sepolia
```

Under the hood you can run:
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

Note: Make sure your `.env` contains PRIVATE_KEY, SEPOLIA_RPC_URL, and MARKETING_WALLET. The script will print the deployed contract address after successful deployment — copy it for verification and further interaction.

Verify on Etherscan
After deploying, you can verify the contract on Etherscan (if ETHERSCAN_API_KEY is set):

```bash
npx hardhat verify --network sepolia DEPLOYED_ADDRESS "0xMarketingWallet"
```

Replace `DEPLOYED_ADDRESS` with the address printed after deployment and replace the constructor arg with your marketing wallet (or leave quotes as a single string if required).

Interacting with the contract
You can interact via:
- Hardhat console
- Ethers.js / Web3 scripts
- Frontend connected to Sepolia

Example (Hardhat console):
```bash
npx hardhat console --network sepolia
> const [deployer] = await ethers.getSigners()
> const Token = await ethers.getContractFactory("PorkelonToken")
> const token = Token.attach("DEPLOYED_ADDRESS")
> await token.transfer("0xrecipient", ethers.utils.parseUnits("1000", 18))
```

When transfers happen, 1% of the amount is automatically sent to the configured marketing wallet (as part of the token's transfer logic).

Environment variables (recommended)
Add to `.env`:
```
PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
MARKETING_WALLET=0xYourMarketingWalletAddress
ETHERSCAN_API_KEY=YourEtherscanApiKey
```

Security & notes
- This repository targets Sepolia (testnet); do not use testnet keys or funds on mainnet without audit.
- The marketing fee is implemented in transfer logic and routes to the MARKETING_WALLET. Ensure you understand this behavior before sending large amounts.
- Do not commit private keys or secrets. Use environment vars and secret managers.
- This contract is intended for testing and demonstration. If you plan to deploy on mainnet, consider a professional audit.

Contributing
- Bug reports and PRs are welcome.
- Keep changes small and focused; include tests for new behavior.
- Update README and docs when adding features.

License & contact
- License: MIT (or update to your preferred license)
- Author: erikg713 — https://github.com/erikg713
