const { ethers } = require("hardhat");

async function main() {
  const LP_TOKEN = "YOUR_LP_TOKEN_ADDRESS"; // Get from add_liquidity tx logs or QuickSwap factory
  const UNICRYPT_LOCKER = "0xaDB2437e6F65682B2a7f4AFd03Cb86DeB3f6b143508A7B1D0";
  const LOCK_DURATION = 365 * 24 * 60 * 60; // 1 year in seconds
  const LP_AMOUNT = ethers.parseUnits("YOUR_LP_AMOUNT", 18); // Full LP balance; adjust

  const lp = await ethers.getContractAt("IERC20", LP_TOKEN);
  const locker = await ethers.getContractAt("IUnicryptLocker", UNICRYPT_LOCKER); // Need interface below

  // Approve LP to locker
  await lp.approve(UNICRYPT_LOCKER, LP_AMOUNT);
  console.log("Approved LP for locking");

  // Lock (assumes Unicrypt's lock function; confirm ABI on PolygonScan)
  // Typical: lockLPToken(lpToken, amount, unlock_date, referrer, fee, withDrawer)
  const unlockDate = Math.floor(Date.now() / 1000) + LOCK_DURATION;
  await locker.lockLPToken(LP_TOKEN, LP_AMOUNT, unlockDate, ethers.ZeroAddress, true, await ethers.provider.getSigner().getAddress());
  console.log("Liquidity locked for 1 year");
}

// Unicrypt Locker Interface (basic; expand as needed from contract ABI)
const IUnicryptLocker = new ethers.Interface([
  "function lockLPToken(address _lpToken, uint256 _amount, uint256 _unlock_date, address payable _referral, bool _fee_in_eth, address payable _withdrawer)"
]);

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
