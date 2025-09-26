// tests/Porkelon.test.js
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Porkelon Ecosystem", function () {
  let deployer, teamWallet, presaleWallet, airdropWallet, stakingWallet, marketingWallet, liquidityWallet, user;
  let porkelon, presale, airdrop, staking, locker, vault;
  let usdt;

  beforeEach(async function () {
    [deployer, teamWallet, presaleWallet, airdropWallet, stakingWallet, marketingWallet, liquidityWallet, user] = await ethers.getSigners();

    // Mock USDT contract
    const USDT = await ethers.getContractFactory("MockERC20");
    usdt = await USDT.deploy("USD Tether", "USDT", ethers.parseUnits("1000000", 6));
    await usdt.waitForDeployment();

    // Deploy Porkelon
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

    // Deploy PorkelonPresale
    const PorkelonPresale = await ethers.getContractFactory("PorkelonPresale");
    presale = await upgrades.deployProxy(
      PorkelonPresale,
      [
        tokenAddress,
        usdt.getAddress(),
        ethers.parseEther("0.000001"),
        ethers.parseEther("0.001"),
        ethers.parseEther("0.1"),
        ethers.parseEther("10"),
        startTime,
        endTime,
        ethers.parseEther("10000000000")
      ],
      { initializer: "initialize" }
    );
    await presale.waitForDeployment();

    // Deploy PorkelonAirdrop
    const PorkelonAirdrop = await ethers.getContractFactory("PorkelonAirdrop");
    airdrop = await upgrades.deployProxy(
      PorkelonAirdrop,
      [tokenAddress, ethers.parseEther("5000000000")],
      { initializer: "initialize" }
    );
    await airdrop.waitForDeployment();

    // Deploy PorkelonStakingRewards
    const PorkelonStakingRewards = await ethers.getContractFactory("PorkelonStakingRewards");
    staking = await upgrades.deployProxy(
      PorkelonStakingRewards,
      [tokenAddress, tokenAddress, ethers.parseEther("10000000000")],
      { initializer: "initialize" }
    );
    await staking.waitForDeployment();

    // Deploy PorkelonLiquidityLocker
    const PorkelonLiquidityLocker = await ethers.getContractFactory("PorkelonLiquidityLocker");
    locker = await upgrades.deployProxy(
      PorkelonLiquidityLocker,
      [tokenAddress, liquidityWallet.address, ethers.parseEther("40000000000")],
      { initializer: "initialize" }
    );
    await locker.waitForDeployment();

    // Deploy PorkelonMarketingVault
    const PorkelonMarketingVault = await ethers.getContractFactory("PorkelonMarketingVault");
    vault = await upgrades.deployProxy(
      PorkelonMarketingVault,
      [tokenAddress, marketingWallet.address, 2 * 365 * 24 * 60 * 60],
      { initializer: "initialize" }
    );
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

  it("should allow team wallet to transfer tokens", async function () {
    const amount = ethers.parseEther("1000000000"); // 1B PORK
    await porkelon.connect(teamWallet).transfer(user.address, amount);
    expect(await porkelon.balanceOf(user.address)).to.equal(ethers.parseEther("990000000")); // After 1% fee
    expect(await porkelon.balanceOf(teamWallet.address)).to.equal(ethers.parseEther("24010000000")); // Initial - transfer + fee
  });

  it("should allow presale purchase with MATIC", async function () {
    await ethers.provider.send("evm_increaseTime", [3600]);
    await presale.connect(user).buyWithMatic({ value: ethers.parseEther("1") });
    expect(await porkelon.balanceOf(user.address)).to.equal(ethers.parseEther("1000000"));
    expect(await presale.sold()).to.equal(ethers.parseEther("1000000"));
  });

  it("should allow airdrop distribution", async function () {
    await airdrop.airdropBatch([user.address], [ethers.parseEther("1000")]);
    expect(await porkelon.balanceOf(user.address)).to.equal(ethers.parseEther("1000"));
    expect(await airdrop.airdropPool()).to.equal(ethers.parseEther("4999999000"));
  });

  it("should allow staking and reward claiming", async function () {
    await porkelon.connect(stakingWallet).approve(staking.getAddress(), ethers.parseEther("1000"));
    await staking.connect(stakingWallet).stake(ethers.parseEther("1000"));
    await ethers.provider.send("evm_increaseTime", [86400]);
    await staking.connect(stakingWallet).getReward();
    expect(await porkelon.balanceOf(stakingWallet.address)).to.be.above(ethers.parseEther("9999"));
  });
});

// Mock ERC20 for USDT testing
const MockERC20 = {
  type: "contract",
  contractName: "MockERC20",
  sourceName: "MockERC20.sol",
  abi: [
    {
      inputs: [
        { internalType: "string", name: "name", type: "string" },
        { internalType: "string", name: "symbol", type: "string" },
        { internalType: "uint256", name: "initialSupply", type: "uint256" }
      ],
      stateMutability: "nonpayable",
      type: "constructor"
    },
    {
      anonymous: false,
      inputs: [
        { indexed: true, internalType: "address", name: "owner", type: "address" },
        { indexed: true, internalType: "address", name: "spender", type: "address" },
        { indexed: false, internalType: "uint256", name: "value", type: "uint256" }
      ],
      name: "Approval",
      type: "event"
    },
    {
      anonymous: false,
      inputs: [
        { indexed: true, internalType: "address", name: "from", type: "address" },
        { indexed: true, internalType: "address", name: "to", type: "address" },
        { indexed: false, internalType: "uint256", name: "value", type: "uint256" }
      ],
      name: "Transfer",
      type: "event"
    },
    {
      inputs: [
        { internalType: "address", name: "owner", type: "address" },
        { internalType: "address", name: "spender", type: "address" }
      ],
      name: "allowance",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "view",
      type: "function"
    },
    {
      inputs: [
        { internalType: "address", name: "spender", type: "address" },
        { internalType: "uint256", name: "amount", type: "uint256" }
      ],
      name: "approve",
      outputs: [{ internalType: "bool", name: "", type: "bool" }],
      stateMutability: "nonpayable",
      type: "function"
    },
    {
      inputs: [{ internalType: "address", name: "account", type: "address" }],
      name: "balanceOf",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "view",
      type: "function"
    },
    {
      inputs: [],
      name: "decimals",
      outputs: [{ internalType: "uint8", name: "", type: "uint8" }],
      stateMutability: "view",
      type: "function"
    },
    {
      inputs: [],
      name: "name",
      outputs: [{ internalType: "string", name: "", type: "string" }],
      stateMutability: "view",
      type: "function"
    },
    {
      inputs: [],
      name: "symbol",
      outputs: [{ internalType: "string", name: "", type: "string" }],
      stateMutability: "view",
      type: "function"
    },
    {
      inputs: [],
      name: "totalSupply",
      outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
      stateMutability: "view",
      type: "function"
    },
    {
      inputs: [
        { internalType: "address", name: "to", type: "address" },
        { internalType: "uint256", name: "amount", type: "uint256" }
      ],
      name: "transfer",
      outputs: [{ internalType: "bool", name: "", type: "bool" }],
      stateMutability: "nonpayable",
      type: "function"
    },
    {
      inputs: [
        { internalType: "address", name: "from", type: "address" },
        { internalType: "address", name: "to", type: "address" },
        { internalType: "uint256", name: "amount", type: "uint256" }
      ],
      name: "transferFrom",
      outputs: [{ internalType: "bool", name: "", type: "bool" }],
      stateMutability: "nonpayable",
      type: "function"
    }
  ],
  bytecode: "...", // Add actual bytecode if needed
  deployedBytecode: "...", // Add actual deployed bytecode if needed
  source: `
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.24;

    import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

    contract MockERC20 is ERC20 {
        constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
            _mint(msg.sender, initialSupply);
        }
    }
  `
};
