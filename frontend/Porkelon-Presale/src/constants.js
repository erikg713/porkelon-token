// Lightweight constants and configuration gathered in one place.
// Update PRESALE_ADDRESS and PORK_ADDRESS after deployment.
export const PRESALE_ADDRESS = '0xYOUR_DEPLOYED_PRESALE_ADDRESS_HERE';
export const PORK_ADDRESS = '0xYOUR_DEPLOYED_PORK_ADDRESS_HERE';
export const USDT_ADDRESS = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
export const USDT_ABI = ['function approve(address spender, uint256 amount) public returns (bool)', 'function allowance(address owner, address spender) view returns (uint256)'];

export const CHAIN_ID = 137; // Polygon
export const RPC = 'https://polygon-rpc.com';
export const EXPLORER_TX = (tx) => `https://polygonscan.com/tx/${tx}`;
export const EXPLORER_ADDRESS = (a) => `https://polygonscan.com/address/${a}`;

export const RATE = 100000; // 1 => 100,000 PORK
export const CAP_DISPLAY = 500_000_000;
export const PER_WALLET_CAP = 10_000_000;

export const MIN_MATIC = 0.1;
export const MAX_MATIC = 5;
export const USDT_DECIMALS = 6;
