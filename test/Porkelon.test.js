const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Porkelon Ecosystem", function () {
  let deployer, teamWallet, presaleWallet, airdropWallet, stakingWallet, marketingWallet, liquidityWallet;
  let porkelon, presale, airdrop, staking, locker, vault;

  beforeEach(async function () {
    [deployer, teamWallet, presaleWallet, airdropWallet, stakingWallet, marketingWallet, liquidityWallet] = await ethers.getSigners();

    const Porkelon = await ethers.getContractFactory("Porkelon");
    porkelon = await upgrades.deployProxy(
      Porkelon,
      [teamWallet.address, presaleWallet.address, airdropWallet.address, stakingWallet.address, marketingWallet.address, liquidityWallet.address],
      { initializer: "initialize", kind: "uups" }
    );
    await porkelon.waitForDeployment();

    const tokenAddress = await porkelon.getAddress();
    const startTime = Math.floor(Date.now() / 1000) + 60;
    const endTime = startTime + 7 * 24 * 60 * 60;
    const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
    presale = await PorkelonPresale.deploy(
      tokenAddress,
      "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
      ethers.parseEther("0.000001"),
      ethers.parseEther("0.001"),
      ethers.parseEther("0.1"),
      ethers.parseEther("10"),
      startTime,
      endTime,
      ethers.parseEther("10000000000")
    );
    await presale.waitForDeployment();

    const PorkelonAirdrop = await ethers.getContractFactory("PorkelonAirdrop");
    airdrop = await PorkelonAirdrop.deploy(tokenAddress, ethers.parseEther("5000000000"));
    await airdrop.waitForDeployment();

    const PorkelonStakingRewards = await ethers.getContractFactory("PorkelonStakingRewards");
    staking = await PorkelonStakingRewards.deploy(tokenAddress, tokenAddress, ethers.parseEther("10000000000"));
    await staking.waitForDeployment();

    const PorkelonLiquidityLocker = await ethers.getContractFactory("PorkelonLiquidityLocker");
    locker = await PorkelonLiquidityLocker.deploy(tokenAddress, liquidityWallet.address, ethers.parseEther("40000000000"));
    await locker.waitForDeployment();

    const PorkelonMarketingVault = await ethers.getContractFactory("PorkelonMarketingVault");
    vault = await PorkelonMarketingVault.deploy(tokenAddress, marketingWallet.address, 2 * 365 * 24 * 60 * 60);
    await vault.waitForDeployment();
  });

  it("should deploy with correct allocations", async function () {
    expect(await porkelon.balanceOf(teamWallet.address)).to.equal(ethers.parseEther("25000000000"));
    expect(await porkelon.balanceOf(presaleWallet.address)).to.equal(ethers.parseEther("10000000000"));
    expect(await porkelon.balanceOf(airdropWallet.address)).to.equal(ethers.parseEther("5000000000"));
    expect(await porkelon.balanceOf(stakingWallet.address)).to.equal(ethers.parseEther("10000000000"));
    expect(await porkelon.balanceOf(marketingWallet.address)).to.equal(ethers.parseEther("10000000000"));
    expect(await porkelon.balanceOf(liquidityWallet.address)).to.equal(ethers.parseEther("40000000000"));
  });

  it("should apply 1% transfer fee", async function () {
    await porkelon.connect(presaleWallet).transfer(deployer.address, ethers.parseEther("1000"));
    expect(await porkelon.balanceOf(deployer.address)).to.equal(ethers.parseEther("990"));
    expect(await porkelon.balanceOf(teamWallet.address)).to.equal(ethers.parseEther("25000000010"));
  });
});
