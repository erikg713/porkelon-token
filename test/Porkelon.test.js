// test/Porkelon.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// Mock ABIs for external contracts
const UNISWAP_V3_FACTORY_ABI = [
  "function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool)",
  "function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool)"
];

const NONFUNGIBLE_POSITION_MANAGER_ABI = [
  "function mint((address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline)) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)",
  "function collect((uint256 tokenId, address recipient, uint128 amount0Max, uint128 amount1Max)) external returns (uint256 amount0, uint256 amount1)",
  "function positions(uint256 tokenId) external view returns (uint96, address, address, address, uint24, int24, int24, uint128, uint256, uint256, uint128, uint128)"
];

const WMATIC_ABI = [
  "function deposit() external payable",
  "function withdraw(uint256 wad) external"
];

describe("Porkelon Contract", function () {
  async function deployPorkelonFixture() {
    const [owner, multisig, user1, user2] = await ethers.getSigners();

    // Deploy mocks
    const MockUniswapV3Factory = await ethers.getContractFactory("contracts/MockUniswapV3Factory.sol:MockUniswapV3Factory");
    const mockFactory = await MockUniswapV3Factory.deploy();

    const MockNonfungiblePositionManager = await ethers.getContractFactory("contracts/MockNonfungiblePositionManager.sol:MockNonfungiblePositionManager");
    const mockPositionManager = await MockNonfungiblePositionManager.deploy();

    const MockWMATIC = await ethers.getContractFactory("contracts/MockWMATIC.sol:MockWMATIC");
    const mockWMATIC = await MockWMATIC.deploy();

    // Deploy Porkelon with mock addresses
    const Porkelon = await ethers.getContractFactory("Porkelon");
    const porkelon = await Porkelon.deploy(multisig.address, "https://porkelon.com/metadata.json");

    // Override constant addresses for testing
    await porkelon.connect(owner).setTestConstants(mockFactory.address, mockPositionManager.address, mockWMATIC.address); // Add this function to contract for testing

    return { porkelon, multisig, user1, user2, mockFactory, mockPositionManager, mockWMATIC };
  }

  describe("Deployment", function () {
    it("Should set the correct name, symbol, and roles", async function () {
      const { porkelon, multisig } = await loadFixture(deployPorkelonFixture);
      expect(await porkelon.name()).to.equal("Porkelon Token");
      expect(await porkelon.symbol()).to.equal("PORK");
      expect(await porkelon.hasRole(await porkelon.DEFAULT_ADMIN_ROLE(), multisig.address)).to.be.true;
      expect(await porkelon.hasRole(await porkelon.MINTER_ROLE(), multisig.address)).to.be.true;
      expect(await porkelon.hasRole(await porkelon.PAUSER_ROLE(), multisig.address)).to.be.true;
    });

    it("Should pre-approve the position manager", async function () {
      const { porkelon, mockPositionManager } = await loadFixture(deployPorkelonFixture);
      expect(await porkelon.allowance(porkelon.address, mockPositionManager.address)).to.equal(ethers.constants.MaxUint256);
      expect(await (await ethers.getContractAt("IERC20", mockWMATIC.address)).allowance(porkelon.address, mockPositionManager.address)).to.equal(ethers.constants.MaxUint256);
    });
  });

  describe("Minting and Airdrop", function () {
    it("Should mint tokens with valid signatures and nonce", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const amount = ethers.utils.parseUnits("1000", 18);
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"]; // Mock valid signatures

      await expect(porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce))
        .to.emit(porkelon, "Transfer")
        .withArgs(ethers.constants.AddressZero, user1.address, amount);

      expect(await porkelon.balanceOf(user1.address)).to.equal(amount);
    });

    it("Should revert mint with used nonce", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const amount = ethers.utils.parseUnits("1000", 18);
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];

      await porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce);
      await expect(porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce))
        .to.be.revertedWith("Nonce already used");
    });

    it("Should revert mint with invalid signatures", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const amount = ethers.utils.parseUnits("1000", 18);
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1"]; // Invalid (only 1)

      await expect(porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce))
        .to.be.revertedWith("Invalid signatures");
    });

    it("Should airdrop tokens to multiple recipients", async function () {
      const { porkelon, multisig, user1, user2 } = await loadFixture(deployPorkelonFixture);
      const recipients = [user1.address, user2.address];
      const amounts = [ethers.utils.parseUnits("500", 18), ethers.utils.parseUnits("500", 18)];
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];

      await expect(porkelon.connect(multisig).airdrop(recipients, amounts, payloadHash, signatures, nonce))
        .to.emit(porkelon, "Transfer")
        .withArgs(ethers.constants.AddressZero, user1.address, amounts[0])
        .to.emit(porkelon, "Transfer")
        .withArgs(ethers.constants.AddressZero, user2.address, amounts[1]);

      expect(await porkelon.balanceOf(user1.address)).to.equal(amounts[0]);
      expect(await porkelon.balanceOf(user2.address)).to.equal(amounts[1]);
    });

    it("Should revert airdrop with array mismatch", async function () {
      const { porkelon, multisig } = await loadFixture(deployPorkelonFixture);
      const recipients = [ethers.constants.AddressZero];
      const amounts = [];
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];

      await expect(porkelon.connect(multisig).airdrop(recipients, amounts, payloadHash, signatures, nonce))
        .to.be.revertedWith("Array length mismatch");
    });
  });

  describe("Staking", function () {
    it("Should stake tokens and update totalStaked", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const amount = ethers.utils.parseUnits("1000", 18);
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];

      await porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce);
      await porkelon.connect(user1).approve(porkelon.address, amount);

      await expect(porkelon.connect(user1).stake(amount))
        .to.emit(porkelon, "Staked")
        .withArgs(user1.address, amount);

      expect(await porkelon.totalStaked()).to.equal(amount);
      expect((await porkelon.stakes(user1.address)).amount).to.equal(amount);
    });

    it("Should unstake tokens and update totalStaked", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const amount = ethers.utils.parseUnits("1000", 18);
      const unstakeAmount = ethers.utils.parseUnits("500", 18);
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];

      await porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce);
      await porkelon.connect(user1).approve(porkelon.address, amount);
      await porkelon.connect(user1).stake(amount);

      await expect(porkelon.connect(user1).unstake(unstakeAmount))
        .to.emit(porkelon, "Unstaked")
        .withArgs(user1.address, unstakeAmount);

      expect(await porkelon.totalStaked()).to.equal(amount.sub(unstakeAmount));
      expect((await porkelon.stakes(user1.address)).amount).to.equal(amount.sub(unstakeAmount));
    });

    it("Should claim rewards after funding and time passage", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const stakeAmount = ethers.utils.parseUnits("1000", 18);
      const rewardAmount = ethers.utils.parseUnits("10000", 18);
      const rewardRate = ethers.utils.parseUnits("1", 18); // 1 PORK per second
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];

      await porkelon.connect(multisig).mint(user1.address, stakeAmount, payloadHash, signatures, nonce);
      await porkelon.connect(user1).approve(porkelon.address, stakeAmount);
      await porkelon.connect(user1).stake(stakeAmount);

      await porkelon.connect(multisig).fundRewards(rewardAmount);
      await porkelon.connect(multisig).setRewardRate(rewardRate);

      // Advance time by 10 seconds
      await network.provider.send("evm_increaseTime", [10]);
      await network.provider.send("evm_mine");

      const pending = await porkelon.pendingRewards(user1.address);
      expect(pending).to.be.closeTo(ethers.utils.parseUnits("10", 18), ethers.utils.parseUnits("0.1", 18)); // ~10 PORK

      await expect(porkelon.connect(user1).claimRewards())
        .to.emit(porkelon, "RewardsClaimed")
        .withArgs(user1.address, pending);

      expect(await porkelon.balanceOf(user1.address)).to.equal(pending);
    });

    it("Should revert stake with zero amount", async function () {
      const { porkelon, user1 } = await loadFixture(deployPorkelonFixture);
      await expect(porkelon.connect(user1).stake(0)).to.be.revertedWith("Amount must be greater than zero");
    });

    it("Should revert unstake with insufficient amount", async function () {
      const { porkelon, user1 } = await loadFixture(deployPorkelonFixture);
      await expect(porkelon.connect(user1).unstake(1)).to.be.revertedWith("Insufficient staked amount");
    });

    it("Should revert claim with no rewards", async function () {
      const { porkelon, user1 } = await loadFixture(deployPorkelonFixture);
      await expect(porkelon.connect(user1).claimRewards()).to.be.revertedWith("No rewards to claim");
    });
  });

  describe("Liquidity Pool", function () {
    it("Should create liquidity pool if not exists", async function () {
      const { porkelon, multisig, mockFactory } = await loadFixture(deployPorkelonFixture);

      // Mock factory to return zero first, then create pool
      await mockFactory.setPool(ethers.constants.AddressZero);

      await expect(porkelon.connect(multisig).createLiquidityPool())
        .to.emit(porkelon, "LiquidityPoolCreated");

      expect(await porkelon.liquidityPool()).to.not.equal(ethers.constants.AddressZero);
    });

    it("Should use existing pool if available", async function () {
      const { porkelon, multisig, mockFactory } = await loadFixture(deployPorkelonFixture);
      const mockPool = "0xMockPoolAddress";

      await mockFactory.setPool(mockPool);

      await expect(porkelon.connect(multisig).createLiquidityPool())
        .to.emit(porkelon, "LiquidityPoolCreated")
        .withArgs(mockPool);

      expect(await porkelon.liquidityPool()).to.equal(mockPool);
    });

    it("Should add liquidity and emit event", async function () {
      const { porkelon, multisig, mockPositionManager, mockWMATIC } = await loadFixture(deployPorkelonFixture);
      const amountPORK = ethers.utils.parseUnits("1000", 18);
      const amountMATIC = ethers.utils.parseUnits("1", 18);
      const tickLower = -60000;
      const tickUpper = 60000;
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      // Mint tokens to contract for liquidity
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];
      await porkelon.connect(multisig).mint(porkelon.address, amountPORK, payloadHash, signatures, nonce);

      // Set mock responses
      await mockPositionManager.setMintResponse(1, 100, amountPORK, amountMATIC); // tokenId, liquidity, amount0, amount1

      await expect(porkelon.connect(multisig).addLiquidity(amountPORK, amountMATIC, tickLower, tickUpper, deadline, { value: amountMATIC }))
        .to.emit(porkelon, "LiquidityAdded")
        .withArgs(1, 100, amountPORK, amountMATIC);

      const positionIds = await porkelon.getLiquidityPositionIds();
      expect(positionIds[0]).to.equal(1);
    });

    it("Should collect fees from position", async function () {
      const { porkelon, multisig, mockPositionManager } = await loadFixture(deployPorkelonFixture);
      const tokenId = 1;
      const amount0Max = ethers.constants.MaxUint256;
      const amount1Max = ethers.constants.MaxUint256;
      const amount0 = ethers.utils.parseUnits("10", 18);
      const amount1 = ethers.utils.parseUnits("0.1", 18);

      // Add a position ID
      await porkelon.connect(multisig).pushTestPositionId(tokenId); // Add helper function for testing

      // Set mock collect response
      await mockPositionManager.setCollectResponse(amount0, amount1);

      await expect(porkelon.connect(multisig).collectFees(tokenId, amount0Max, amount1Max))
        .to.emit(porkelon, "FeesCollected")
        .withArgs(tokenId, amount0, amount1);

      // Check balances transferred to multisig
      expect(await porkelon.balanceOf(multisig.address)).to.equal(amount0); // Assuming amount0 is PORK
    });

    it("Should revert addLiquidity without pool", async function () {
      const { porkelon, multisig } = await loadFixture(deployPorkelonFixture);
      await expect(porkelon.connect(multisig).addLiquidity(1, 1, 0, 0, 0)).to.be.revertedWith("Pool not created");
    });
  });

  describe("Burn and Pause", function () {
    it("Should burn tokens", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const amount = ethers.utils.parseUnits("1000", 18);
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];

      await porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce);

      await expect(porkelon.connect(user1).burn(amount / 2))
        .to.emit(porkelon, "Transfer")
        .withArgs(user1.address, ethers.constants.AddressZero, amount / 2);

      expect(await porkelon.balanceOf(user1.address)).to.equal(amount / 2);
    });

    it("Should pause and unpause contract", async function () {
      const { porkelon, multisig, user1 } = await loadFixture(deployPorkelonFixture);
      const amount = ethers.utils.parseUnits("1000", 18);

      await porkelon.connect(multisig).pause();
      await expect(porkelon.connect(user1).stake(amount)).to.be.revertedWith("Pausable: paused");

      await porkelon.connect(multisig).unpause();
      // Mint and approve for stake
      const nonce = ethers.utils.formatBytes32String("testnonce");
      const payloadHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      const signatures = ["0xSig1", "0xSig2"];
      await porkelon.connect(multisig).mint(user1.address, amount, payloadHash, signatures, nonce);
      await porkelon.connect(user1).approve(porkelon.address, amount);
      await expect(porkelon.connect(user1).stake(amount)).to.not.be.reverted;
    });
  });

  describe("Metadata", function () {
    it("Should set metadata URI", async function () {
      const { porkelon, multisig } = await loadFixture(deployPorkelonFixture);
      const newURI = "https://new-metadata.com";

      await expect(porkelon.connect(multisig).setMetadata(newURI))
        .to.emit(porkelon, "MetadataUpdated")
        .withArgs(newURI);

      expect(await porkelon.metadataURI()).to.equal(newURI);
    });

    it("Should revert setMetadata from non-admin", async function () {
      const { porkelon, user1 } = await loadFixture(deployPorkelonFixture);
      await expect(porkelon.connect(user1).setMetadata("test")).to.be.revertedWith("AccessControl: account");
    });
  });
});

// Mock contracts for testing (add these to contracts folder)

// contracts/MockUniswapV3Factory.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockUniswapV3Factory {
  address public pool;
  function setPool(address _pool) external {
    pool = _pool;
  }
  function getPool(address, address, uint24) external view returns (address) {
    return pool;
  }
  function createPool(address, address, uint24) external returns (address) {
    pool = address(this); // Mock pool address
    return pool;
  }
}

// contracts/MockNonfungiblePositionManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockNonfungiblePositionManager {
  uint256 public tokenId;
  uint128 public liquidity;
  uint256 public amount0;
  uint256 public amount1;

  uint256 public collectAmount0;
  uint256 public collectAmount1;

  function setMintResponse(uint256 _tokenId, uint128 _liquidity, uint256 _amount0, uint256 _amount1) external {
    tokenId = _tokenId;
    liquidity = _liquidity;
    amount0 = _amount0;
    amount1 = _amount1;
  }

  function setCollectResponse(uint256 _amount0, uint256 _amount1) external {
    collectAmount0 = _amount0;
    collectAmount1 = _amount1;
  }

  function mint(tuple(address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline)) external returns (uint256, uint128, uint256, uint256) {
    return (tokenId, liquidity, amount0, amount1);
  }

  function collect(tuple(uint256 tokenId, address recipient, uint128 amount0Max, uint128 amount1Max)) external returns (uint256, uint256) {
    return (collectAmount0, collectAmount1);
  }

  function positions(uint256) external view returns (uint96, address, address, address, uint24, int24, int24, uint128, uint256, uint256, uint128, uint128) {
    return (0, address(0), address(0), address(0), 0, 0, 0, liquidity, 0, 0, amount0, amount1);
  }
}

// contracts/MockWMATIC.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockWMATIC {
  mapping(address => uint256) public balanceOf;

  function deposit() external payable {
    balanceOf[msg.sender] += msg.value;
  }

  function withdraw(uint256 wad) external {
    require(balanceOf[msg.sender] >= wad, "Insufficient balance");
    balanceOf[msg.sender] -= wad;
    payable(msg.sender).transfer(wad);
  }
}

// Add to Pork
