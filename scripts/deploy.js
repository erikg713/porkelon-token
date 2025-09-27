const { ethers, upgrades } = require("hardhat");

async function main() {
    // Define wallet addresses (replace with actual addresses)
    const devWallet = "0xYourDevWalletAddressHere";
    const stakingWallet = "0xYourStakingWalletAddressHere";
    const liquidityWallet = "0xYourLiquidityWalletAddressHere";
    const marketingWallet = "0xYourMarketingWalletAddressHere";
    const airdropWallet = "0xYourAirdropWalletAddressHere";
    const presaleWallet = "0xYourPresaleWalletAddressHere";

    // Deploy PorkelonPolygon with UUPS proxy
    const PorkelonPolygon = await ethers.getContractFactory("PorkelonPolygon");
    console.log("Deploying PorkelonPolygon proxy...");
    const porkelon = await upgrades.deployProxy(
        PorkelonPolygon,
        [],
        {
            initializer: "initialize",
            kind: "uups",
            constructorArgs: [devWallet, stakingWallet, liquidityWallet, marketingWallet, airdropWallet, presaleWallet],
        }
    );
    await porkelon.deployed();
    console.log("PorkelonPolygon deployed to:", porkelon.address);

    // Deploy Presale contract
    const Presale = await ethers.getContractFactory("Presale");
    console.log("Deploying Presale...");
    const presale = await Presale.deploy(porkelon.address);
    await presale.deployed();
    console.log("Presale deployed to:", presale.address);

    // Transfer presale tokens to Presale contract
    const presaleAmount = ethers.utils.parseEther("10000000000"); // 10B PORK
    await porkelon.transfer(presale.address, presaleAmount);
    console.log("Transferred 10B PORK to Presale contract");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
