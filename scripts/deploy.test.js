const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

async function main() {
  const NAME = "Porkelon";
  const SYMBOL = "PORK";
  const DECIMALS = 18;
  const RECEIVER = process.env.DEPLOYER_ADDRESS;

  const supply = ethers.BigNumber.from("25000000000").mul(
    ethers.BigNumber.from("10").pow(DECIMALS)
  );

  const Porkelon = await ethers.getContractFactory("Porkelon");
  const proxy = await upgrades.deployProxy(
    Porkelon,
    [NAME, SYMBOL, RECEIVER, supply],
    { initializer: "initialize", kind: "uups" }
  );
  await proxy.deployed();

  console.log("Proxy deployed at:", proxy.address);
  console.log(
    "Implementation:",
    await upgrades.erc1967.getImplementationAddress(proxy.address)
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
