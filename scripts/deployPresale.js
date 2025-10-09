const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying Presale contract with account:", deployer.address);

  // Replace with your actual token addresses
  const PORK_ADDRESS = "0xYourPorkTokenAddressHere";
  const USDT_ADDRESS = "0xYourUSDTAddressHere";

  const Presale = await hre.ethers.getContractFactory("Presale");
  const presale = await Presale.deploy(PORK_ADDRESS, USDT_ADDRESS);

  await presale.deployed();
  console.log("Presale contract deployed at:", presale.address);

  // -------------------------
  // Auto-verify on PolygonScan
  // -------------------------
  console.log("Waiting 60s for PolygonScan indexing...");
  await new Promise((resolve) => setTimeout(resolve, 60000)); // wait 60s

  try {
    console.log("Verifying contract...");
    await hre.run("verify:verify", {
      address: presale.address,
      constructorArguments: [PORK_ADDRESS, USDT_ADDRESS],
    });
    console.log("Verification successful ✅");
  } catch (err) {
    console.log("Verification failed (may be already verified):", err.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
