const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Using account:", deployer.address);

  // Replace these!
  const LP_TOKEN = "0x23cE6D1E06D8509A5668e9E1602de1c2b19ba3a2"; 
  const UNICRYPT_LOCKER = "0xaDB2437e6F65682B2a7f4AFd03Cb86DeB3f6b143508A7B1D0";
  const LOCK_DURATION = 365 * 24 * 60 * 60; // 1 year
  const LP_AMOUNT = ethers.parseUnits("100", 18); // e.g. 100 LP tokens

  // ABIs
  const ERC20_ABI = [
    "function approve(address spender, uint256 amount) external returns (bool)"
  ];
  const UNICRYPT_ABI = [
    "function lockLPToken(address _lpToken, uint256 _amount, uint256 _unlock_date, address _referral, bool _fee_in_eth, address _withdrawer) external"
  ];

  // Contract instances
  const lp = new ethers.Contract(LP_TOKEN, ERC20_ABI, deployer);
  const locker = new ethers.Contract(UNICRYPT_LOCKER, UNICRYPT_ABI, deployer);

  // 1. Approve LP to Unicrypt
  const approveTx = await lp.approve(UNICRYPT_LOCKER, LP_AMOUNT);
  await approveTx.wait();
  console.log(`✅ Approved ${LP_AMOUNT} LP tokens to locker`);

  // 2. Lock LP
  const unlockDate = Math.floor(Date.now() / 1000) + LOCK_DURATION;
  const lockTx = await locker.lockLPToken(
    LP_TOKEN,
    LP_AMOUNT,
    unlockDate,
    ethers.ZeroAddress,   // no referral
    true,                 // fee in ETH (MATIC on Polygon)
    deployer.address      // withdrawer
  );
  await lockTx.wait();
  console.log(`✅ Locked ${LP_AMOUNT} LP tokens until ${new Date(unlockDate * 1000).toUTCString()}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
