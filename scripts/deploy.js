async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const marketingWallet = process.env.MARKETING_WALLET;
  if (!marketingWallet) throw new Error("Set MARKETING_WALLET in .env");

  const Porkelon = await ethers.getContractFactory("PorkelonToken");
  const token = await Porkelon.deploy(marketingWallet);
  await token.deployed();

  console.log("✅ PorkelonToken deployed at:", token.address);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
