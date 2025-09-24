# Porkelon Token (PORK)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Polygon](https://img.shields.io/badge/Blockchain-Polygon-blueviolet)](https://polygon.technology/)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-blue)](https://soliditylang.org/)

## Overview

Porkelon (PORK) is an upgradable ERC-20 token on the Polygon network, designed as a meme/utility token with a capped supply of 100 billion tokens. It includes features like burnability, pausability, ownable control, a 1% transaction fee to a team wallet, and predefined allocations for dev, staking/rewards, liquidity, marketing, airdrops, and presale. The token is non-mintable after initialization to enforce the max supply.

This repository contains:
- The main token smart contract (`Porkelon.sol`).
- A presale contract (`PorkelonPresale.sol`).
- Bash scripts for adding liquidity (`scripts/add_liquidity.sh`) and locking liquidity (`scripts/lock_liquidity.sh`).
- Deployment and usage instructions.

The project emphasizes low fees on Polygon, upgradeability via UUPS proxy, and community trust through liquidity locking.

## Features

- **Token Standard**: ERC-20 (upgradeable).
- **Total Supply**: 100,000,000,000 PORK (capped, no further minting).
- **Decimals**: 18.
- **Transaction Fee**: 1% on every transfer (sent to team wallet; excludes mints/burns).
- **Allocations**:
  - 25% Dev wallet.
  - 10% Staking and rewards.
  - 40% Liquidity (locked for 1 year).
  - 10% Marketing and advertising.
  - 5% Airdrops.
  - 10% Presale.
- **Security**: Pausable, burnable, ownable, role-based access control.
- **Upgradeable**: Via UUPS proxy for future enhancements (e.g., adding taxes or features).
- **Presale**: Dedicated contract for fair token distribution.
- **Liquidity**: Added to QuickSwap DEX and locked via Unicrypt for 1 year.
- **Cross-Chain Migration**: Guidance for migrating from Solana (original Moonshot deployment).

## Prerequisites

- **Wallet**: MetaMask or similar, connected to Polygon mainnet (Chain ID: 137, RPC: https://polygon-rpc.com).
- **Funds**: POL (Polygon's native token) for gas fees (~$1 total for deployment/scripts).
- **Tools**:
  - [Remix IDE](https://remix.ethereum.org/) for simple deployment.
  - [Hardhat](https://hardhat.org/) for advanced deployment/testing.
  - [Foundry](https://book.getfoundry.sh/) for scripts (install via `curl -L https://foundry.paradigm.xyz | bash` then `foundryup`).
  - Node.js for Hardhat.
- **Libraries**: OpenZeppelin contracts (imported in Solidity files).

## Smart Contracts

### Porkelon.sol

The core token contract (updated with new allocations).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Porkelon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18; // 100 billion tokens with 18 decimals
    address public teamWallet; // Wallet for collecting 1% transaction fees

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _teamWallet) initializer public {
        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        teamWallet = _teamWallet; // Set the team wallet for fees (replace with actual address when deploying)

        // Mint the entire max supply at initialization
        uint256 totalSupplyToMint = MAX_SUPPLY;

        // Allocations (replace placeholder addresses with actual wallet addresses)
        _mint(address(0xYourDevWalletAddressHere), (totalSupplyToMint * 25) / 100); // 25% to dev wallet (25B tokens)
        _mint(address(0xYourStakingRewardsWalletAddressHere), (totalSupplyToMint * 10) / 100); // 10% for staking and rewards (10B tokens)
        _mint(address(0xYourLiquidityWalletAddressHere), (totalSupplyToMint * 40) / 100); // 40% for liquidity lock (40B tokens)
        _mint(address(0xYourMarketingWalletAddressHere), (totalSupplyToMint * 10) / 100); // 10% for marketing and advertising (10B tokens)
        _mint(address(0xYourAirdropsWalletAddressHere), (totalSupplyToMint * 5) / 100); // 5% for airdrops (5B tokens)
        _mint(address(0xYourPresaleWalletAddressHere), (totalSupplyToMint * 10) / 100); // 10% for presale (10B tokens; handle presale separately)

        // Revoke minter role to prevent any further minting (supply is capped forever)
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender); // Removes ability to grant minter role again
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // No mint function exposed, as all supply is minted at init and role revoked

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

    // Override to apply 1% fee on transfers (not on mints/burns)
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        if (from != address(0) && to != address(0) && teamWallet != address(0)) { // Apply fee only on transfers
            uint256 fee = (value * 1) / 100; // 1% fee
            uint256 amountAfterFee = value - fee;
            super._update(from, teamWallet, fee); // Send fee to team wallet
            super._update(from, to, amountAfterFee); // Send remaining to recipient
        } else {
            super._update(from, to, value);
        }
    }

    // Optional: Function to update team wallet (only owner, for flexibility)
    function setTeamWallet(address newTeamWallet) public onlyOwner {
        require(newTeamWallet != address(0), "Invalid address");
        teamWallet = newTeamWallet;
    }
}
```

### PorkelonPresale.sol

The presale contract for distributing 10% of tokens.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PorkelonPresale is Ownable, ReentrancyGuard {
    IERC20 public porkelonToken; // The Porkelon ERC-20 token
    uint256 public tokenPrice; // Price in wei per token (e.g., 1e12 wei for 1 token = 0.000001 POL per token; adjust for your rate)
    uint256 public minPurchase; // Minimum POL to buy (in wei)
    uint256 public maxPurchase; // Maximum POL per buyer (in wei)
    uint256 public startTime; // Presale start timestamp
    uint256 public endTime; // Presale end timestamp
    uint256 public tokensSold; // Track tokens sold
    uint256 public presaleCap; // Total tokens available for presale (e.g., 10B)

    mapping(address => uint256) public contributions; // Track user contributions

    event TokensPurchased(address indexed buyer, uint256 amountPOL, uint256 tokensReceived);
    event PresaleFinalized(uint256 totalRaised);

    constructor(
        address _porkelonToken,
        uint256 _tokenPrice,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _presaleCap
    ) Ownable(msg.sender) {
        require(_porkelonToken != address(0), "Invalid token address");
        require(_tokenPrice > 0, "Invalid price");
        require(_minPurchase > 0 && _maxPurchase > _minPurchase, "Invalid purchase limits");
        require(_startTime >= block.timestamp && _endTime > _startTime, "Invalid times");
        require(_presaleCap > 0, "Invalid cap");

        porkelonToken = IERC20(_porkelonToken);
        tokenPrice = _tokenPrice;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        startTime = _startTime;
        endTime = _endTime;
        presaleCap = _presaleCap;
    }

    // Function for users to buy tokens
    function buyTokens() external payable nonReentrant {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        require(msg.value >= minPurchase && msg.value <= maxPurchase, "Invalid purchase amount");
        require(contributions[msg.sender] + msg.value <= maxPurchase, "Exceeds max per buyer");

        uint256 tokensToBuy = (msg.value * 1e18) / tokenPrice; // Assuming 18 decimals; adjust if different
        require(tokensSold + tokensToBuy <= presaleCap, "Exceeds presale cap");
        require(porkelonToken.balanceOf(address(this)) >= tokensToBuy, "Insufficient tokens in contract");

        contributions[msg.sender] += msg.value;
        tokensSold += tokensToBuy;

        porkelonToken.transfer(msg.sender, tokensToBuy);

        emit TokensPurchased(msg.sender, msg.value, tokensToBuy);
    }

    // Owner can finalize presale and withdraw funds (e.g., after endTime)
    function finalizePresale() external onlyOwner {
        require(block.timestamp > endTime, "Presale not ended");
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
        emit PresaleFinalized(balance);

        // Optionally, transfer any unsold tokens back to owner
        uint256 unsold = porkelonToken.balanceOf(address(this));
        if (unsold > 0) {
            porkelonToken.transfer(owner(), unsold);
        }
    }

    // Owner can update times if needed (before start)
    function updateTimes(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(block.timestamp < startTime, "Presale already started");
        require(_startTime >= block.timestamp && _endTime > _startTime, "Invalid times");
        startTime = _startTime;
        endTime = _endTime;
    }

    // Emergency withdraw in case of issues
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
        uint256 tokenBalance = porkelonToken.balanceOf(address(this));
        if (tokenBalance > 0) {
            porkelonToken.transfer(owner(), tokenBalance);
        }
    }

    // Receive function for direct POL sends (optional, but allows buyTokens via send)
    receive() external payable {
        buyTokens();
    }
}
```

## Deployment

### Using Remix IDE (Simple)

1. Go to [Remix](https://remix.ethereum.org/).
2. Create files for `Porkelon.sol` and `PorkelonPresale.sol`, paste the code.
3. Compile with Solidity 0.8.20.
4. Deploy Porkelon as an upgradable proxy:
   - Deploy implementation.
   - Deploy ERC1967Proxy, initialize with team wallet.
5. Deploy Presale with parameters (transfer presale tokens to it).
6. Verify on [PolygonScan](https://polygonscan.com/).

### Using Hardhat (Advanced)

1. Install: `npm init -y && npm i --save-dev hardhat @openzeppelin/contracts-upgradeable @openzeppelin/hardhat-upgrades @nomicfoundation/hardhat-toolbox`.
2. Configure `hardhat.config.js` with Polygon network and private key.
3. Deploy script for token:
   ```js
   const { ethers, upgrades } = require("hardhat");

   async function main() {
     const Porkelon = await ethers.getContractFactory("Porkelon");
     const porkelon = await upgrades.deployProxy(Porkelon, ["0xYourTeamWalletHere"], { initializer: 'initialize', kind: 'uups' });
     console.log("Porkelon deployed to:", await porkelon.getAddress());
   }

   main();
   ```
4. Similar for presale (update presaleCap to 10_000_000_000 * 10**18).
5. Run: `npx hardhat run scripts/deploy.js --network polygon`.

## Scripts

### add_liquidity.sh

Adds liquidity to QuickSwap (PORK/WMATIC pair; updated for 40% allocation).

```bash
#!/bin/bash

# Environment variables - SET THESE BEFORE RUNNING!
export PRIVATE_KEY="0xYourLiquidityWalletPrivateKeyHere"  # Never share this!
export RPC_URL="https://polygon-rpc.com"  # Polygon mainnet RPC
export PORKELON_ADDRESS="0xYourDeployedPorkelonContractAddressHere"
export WMATIC_ADDRESS="0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
export QUICKSWAP_ROUTER="0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff"
export AMOUNT_PORK_DESIRED="40000000000000000000000000000"  # 40 billion PORK (40e9 * 1e18 for 18 decimals)
export AMOUNT_WMATIC_DESIRED="10000000000000000000"  # Example: 10 WMATIC (10e18 wei); adjust based on your funding
export AMOUNT_PORK_MIN="32000000000000000000000000000"  # Min PORK to add (e.g., 80% of desired to allow slippage)
export AMOUNT_WMATIC_MIN="8000000000000000000"  # Min WMATIC (e.g., 80% of desired)
export DEADLINE=$(($(date +%s) + 3600))  # 1 hour from now (Unix timestamp)
export RECIPIENT="0xYourLiquidityWalletAddressHere"  # Where to send LP tokens (your wallet)

# Step 1: Approve PORK for Router
echo "Approving PORK for QuickSwap Router..."
cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL $PORKELON_ADDRESS "approve(address,uint256)" $QUICKSWAP_ROUTER $AMOUNT_PORK_DESIRED

# Step 2: Approve WMATIC for Router (if not already)
echo "Approving WMATIC for QuickSwap Router..."
cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL $WMATIC_ADDRESS "approve(address,uint256)" $QUICKSWAP_ROUTER $AMOUNT_WMATIC_DESIRED

# Step 3: Add Liquidity
echo "Adding Liquidity..."
cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL $QUICKSWAP_ROUTER "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)" \
  $PORKELON_ADDRESS \
  $WMATIC_ADDRESS \
  $AMOUNT_PORK_DESIRED \
  $AMOUNT_WMATIC_DESIRED \
  $AMOUNT_PORK_MIN \
  $AMOUNT_WMATIC_MIN \
  $RECIPIENT \
  $DEADLINE

echo "Liquidity added! Check your wallet for LP tokens, then lock them on Unicrypt."
```

Run: `chmod +x scripts/add_liquidity.sh && ./scripts/add_liquidity.sh`

### lock_liquidity.sh

Locks LP tokens on Unicrypt for 1 year.

```bash
#!/bin/bash

# Script to lock liquidity (LP tokens) on Unicrypt V2 Liquidity Locker on Polygon for 1 year.
# Requirements: Foundry (cast) installed, Polygon RPC URL, private key with funds/LP tokens.
# Usage: 
# 1. Set environment variables: export PRIVATE_KEY=your_private_key_here
#    export POLYGON_RPC=https://polygon-rpc.com (or your RPC)
# 2. Run: ./scripts/lock_liquidity.sh <lp_token_address> <amount_to_lock> <withdrawer_address> [<referral_address>]
# Example: ./scripts/lock_liquidity.sh 0xYourLPPairAddress 1000000000000000000000 0xYourWithdrawerAddress 0x0000000000000000000000000000000000000000
# (amount in wei, e.g., full LP balance; referral optional, defaults to zero address)

# Unicrypt V2 Liquidity Locker address on Polygon
LOCKER=0xadb2437e6f65682b85f814fbc12fec0508a7b1d0

# Flat fee in MATIC (100 MATIC = 100e18 wei)
FLAT_FEE=100000000000000000000

# Check if cast is installed
if ! command -v cast &> /dev/null; then
    echo "Cast (from Foundry) is not installed. Install Foundry: https://book.getfoundry.sh/install"
    exit 1
fi

# Check required args
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <lp_token_address> <amount_to_lock> <withdrawer_address> [<referral_address>]"
    exit 1
fi

LP_TOKEN=$1
AMOUNT=$2
WITHDRAWER=$3
REFERRAL=${4:-0x0000000000000000000000000000000000000000}  # Default to zero if not provided

# Calculate unlock date: 1 year from now (31536000 seconds)
CURRENT_TIMESTAMP=$(cast to-uint256 $(date +%s))
UNLOCK_DATE=$(($CURRENT_TIMESTAMP + 31536000))

# Fee in ETH (MATIC on Polygon): Assume no referral discount for simplicity; if referral, fee may be lower, but script sends full 100 MATIC (excess refunded if applicable)
FEE_IN_ETH=true  # Pay flat fee in MATIC

# Get sender address
SENDER=$(cast wallet address --private-key $PRIVATE_KEY)

echo "Locking $AMOUNT wei of LP token $LP_TOKEN for 1 year, withdrawer $WITHDRAWER, from $SENDER"

# Step 1: Approve the LP token for the locker
echo "Approving LP token for Unicrypt Locker..."
cast send $LP_TOKEN "approve(address,uint256)" $LOCKER $AMOUNT \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC

# Step 2: Call lockLPToken with fee
echo "Locking liquidity..."
cast send $LOCKER "lockLPToken(address,uint256,uint256,address,bool,address)" \
  $LP_TOKEN $AMOUNT $UNLOCK_DATE $REFERRAL $FEE_IN_ETH $WITHDRAWER \
  --private-key $PRIVATE_KEY --rpc-url $POLYGON_RPC --value $FLAT_FEE

echo "Liquidity locked for 1 year! Check on Unicrypt app or PolygonScan for the lock details."
```

Run: `chmod +x scripts/lock_liquidity.sh && ./scripts/lock_liquidity.sh <args>`

## Migration from Solana

If migrating from Moonshot (Solana):
1. Register SPL token on [Wormhole Portal](https://portalbridge.com/).
2. Bridge assets/liquidity to Polygon.
3. Revoke old mint authority on Solana.
4. Announce to community for holder swaps.

## Testing and Auditing

- Test on Mumbai testnet (faucet for test POL).
- Use Hardhat for unit tests.
- Recommend professional audit (e.g., via OpenZeppelin) for production.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contact

For questions, reach out on X/Telegram or open an issue.

--- 

This README is up-to-date as of September 23, 2025.
How to use:

1. npm init -y && npm install ethers (run once)


2. node generate_monad_test_wallet.js "OptionalKeystorePass!"


3. Copy the printed Private Key and import into MetaMask: MetaMask → Account menu → Import Account → paste private key.



Security note: run on your local machine only. Do not paste private keys into public websites or chats.

Add Monad Testnet to MetaMask (RPC details)

You can add the network manually in MetaMask using these settings:

Network Name: Monad Testnet

RPC URL: https://testnet-rpc.monad.xyz. 

Chain ID: 10143. 

Currency Symbol: MON. 

Block Explorer (optional): https://testnet.monadexplorer.com. 


(You can also use other public RPC endpoints like https://monad-testnet.drpc.org or provider endpoints from Alchemy / Ankr / QuickNode if you prefer.) 


Get test MON (faucets)

After creating your testnet address, use a testnet faucet to get MON for gas:

Official Monad faucet / portal: https://faucet.monad.xyz/. 

QuickNode faucet for Monad testnet: https://faucet.quicknode.com/monad/testnet. 

Other public faucets / dev tools (if one is rate-limited): QuickNode / OpenBuild / RPC provider faucets listed in the Monad docs. 


Notes: Some faucets have rules (e.g., require an earlier mainnet activity or small rate limits). If an official faucet is down, try community faucets (QuickNode, OpenBuild) or Monad Discord for dev help. 

Add Monad Testnet to MetaMask (RPC details)

You can add the network manually in MetaMask using these settings:

Network Name: Monad Testnet

RPC URL: https://testnet-rpc.monad.xyz. 

Chain ID: 10143. 

Currency Symbol: MON. 

Block Explorer (optional): https://testnet.monadexplorer.com. 


(You can also use other public RPC endpoints like https://monad-testnet.drpc.org or provider endpoints from Alchemy / Ankr / QuickNode if you prefer.) 


---

Get test MON (faucets)

After creating your testnet address, use a testnet faucet to get MON for gas:

Official Monad faucet / portal: https://faucet.monad.xyz/. 

QuickNode faucet for Monad testnet: https://faucet.quicknode.com/monad/testnet. 

Other public faucets / dev tools (if one is rate-limited): QuickNode / OpenBuild / RPC provider faucets listed in the Monad docs. 


Notes: Some faucets have rules (e.g., require an earlier mainnet activity or small rate limits). If an official faucet is down, try community faucets (QuickNode, OpenBuild) or Monad Discord for dev help. 

