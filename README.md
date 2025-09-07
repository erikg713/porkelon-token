# 🐖 Porkelon Token (PORK)

Porkelon Token is a deflationary ERC-20 with a 1% marketing fee.

- **Ticker:** PORK  
- **Total Supply:** 60,000,000,000 PORK (18 decimals)  
- **Features:** Ownable, Mintable, Burnable, Transferable  
- **Fee:** 1% of all transfers goes to the marketing wallet  
- **Network:** Ethereum Sepolia Testnet  

## 🚀 Deploy

1. Install dependencies:
   ```bash
   npm install

2. Copy .env.example to .env and fill values.


3. Compile contracts:

npx hardhat compile


4. Deploy to Sepolia:

npm run deploy:sepolia


5. Verify on Etherscan:

npx hardhat verify --network sepolia DEPLOYED_ADDRESS "0xMarketingWallet"



✅ Tests

Run unit tests:

npm test


---
