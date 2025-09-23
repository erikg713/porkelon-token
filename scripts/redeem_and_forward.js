// scripts/redeem_and_forward.js
// Usage: node redeem_and_forward.js <vaa_hex_or_base64_file> <wrapped_token_address> <new_porkelon_contract_address>
// Example:
//   node redeem_and_forward.js ./signedVaa.hex 0xWrappedTokenAddr 0xNewPorkelonAddr

require("dotenv").config();
const fs = require("fs");
const { ethers } = require("ethers");

// Wormhole Token Bridge (Polygon) contract address (WTT / TokenBridge). From Wormhole docs.
const TOKEN_BRIDGE_POLYGON_ADDRESS = "0x5a58505a96D1dbf8dF91cB21B54419FC36e93fdE"; // official WTT address for Polygon. 2

// Minimal ABI for token bridge redeem (EVM)
const TOKEN_BRIDGE_ABI = [
  // completeTransfer takes bytes encoded VAA
  "function completeTransfer(bytes memory encodedVm) public payable"
];

// Minimal ERC20 ABI
const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "event Transfer(address indexed from, address indexed to, uint256 value)"
];

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error("Usage: node redeem_and_forward.js <vaa_file> <wrapped_token_address> <new_porkelon_contract>");
    process.exit(1);
  }

  const [vaaPath, wrappedTokenAddr, newPorkAddr] = args;
  if (!process.env.PRIVATE_KEY || !process.env.RPC_URL) {
    console.error(".env must contain PRIVATE_KEY and RPC_URL");
    process.exit(1);
  }

  // Read VAA file. Accept hex (0x...) or base64 — detect
  let vaaData = fs.readFileSync(vaaPath, "utf8").trim();
  let vaaBytes;
  if (vaaData.startsWith("0x")) {
    vaaBytes = ethers.utils.arrayify(vaaData);
  } else if (/^[A-Fa-f0-9]+$/.test(vaaData)) {
    // plain hex without 0x
    vaaBytes = ethers.utils.arrayify("0x" + vaaData);
  } else {
    // assume base64
    vaaBytes = Buffer.from(vaaData, "base64");
  }

  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  console.log("Using wallet:", wallet.address);

  // 1) Submit VAA to token bridge on Polygon (completeTransfer)
  const tokenBridge = new ethers.Contract(TOKEN_BRIDGE_POLYGON_ADDRESS, TOKEN_BRIDGE_ABI, wallet);
  console.log("Submitting VAA to Polygon token bridge at", TOKEN_BRIDGE_POLYGON_ADDRESS);

  // estimate gas & submit
  const tx = await tokenBridge.completeTransfer(vaaBytes, { gasLimit: 800000 });
  console.log("Submitted completeTransfer tx:", tx.hash);
  const receipt = await tx.wait();
  console.log("completeTransfer confirmed in block", receipt.blockNumber);

  // 2) Check wrapped token balance
  const wrapped = new ethers.Contract(wrappedTokenAddr, ERC20_ABI, wallet);
  const balance = await wrapped.balanceOf(wallet.address);
  console.log("Wrapped token balance for", wallet.address, "=", balance.toString());

  if (balance.eq(0)) {
    console.warn("Redeem succeeded but balance is 0 — ensure VAA was for this recipient and token.");
    process.exit(0);
  }

  // 3) Approve new PORK contract to pull tokens (or transfer directly)
  // Option A: transfer wrapped tokens directly into the new contract address (if the contract expects direct transfer)
  // Option B: approve the new contract and call a receive function. We'll do a plain transfer assuming the new contract will accept transfers.

  console.log(`Transferring ${balance.toString()} wrapped tokens to new Porkelon contract: ${newPorkAddr}`);
  const tx2 = await wrapped.transfer(newPorkAddr, balance, { gasLimit: 300000 });
  console.log("Transfer tx:", tx2.hash);
  await tx2.wait();
  console.log("Transfer confirmed. Done.");

  console.log("Redeem + forward complete.");
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
