// scripts/deploy_presale.js
const hre = require("hardhat");

async function main() {
  // Replace with your PORK token address (deployer must hold/mint presale allocation)
  const PORK_TOKEN = "0xYOUR_PORKELON_TOKEN_ADDRESS";
  // Polygon USDT
  const USDT = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

  console.log("Deploying Presale with:");
  console.log("PORK token:", PORK_TOKEN);
  console.log("USDT token :", USDT);

  const Presale = await hre.ethers.getContractFactory("Presale");
  const presale = await Presale.deploy(PORK_TOKEN, USDT);
  await presale.waitForDeployment();

  const presaleAddress = await presale.getAddress();
  console.log("✅ Presale deployed at:", presaleAddress);

  // Next steps (attempt token transfer of CAP to presale)
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", await deployer.getAddress());

  const token = await hre.ethers.getContractAt("IERC20", PORK_TOKEN);
  const cap = hre.ethers.parseUnits("500000000", 18); // 500M

  // attempt to transfer CAP to presale contract
  try {
    const tx = await token.connect(deployer).transfer(presaleAddress, cap);
    await tx.wait();
    console.log("✅ Transferred CAP (500M) to presale contract");
  } catch (err) {
    console.warn("⚠️ Could not transfer CAP to presale contract. Make sure the deployer owns the presale allocation or mint/send tokens to the deployer beforehand.");
  }

  // If your token implements setPresaleContract (like your Porkelon upgradeable), call it:
  try {
    const porkelon = await hre.ethers.getContractAt("Porkelon", PORK_TOKEN);
    const setTx = await porkelon.connect(deployer).setPresaleContract(presaleAddress);
    await setTx.wait();
    console.log("✅ Called setPresaleContract on Porkelon token");
  } catch (err) {
    console.warn("ℹ️ Could not call setPresaleContract — maybe deployer is not owner or token ABI mismatch. If needed, call setPresaleContract(presaleAddress) from the token owner.");
  }

  console.log("Deployment complete. Presale will be active at midnight UTC tonight and run for 30 days.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
