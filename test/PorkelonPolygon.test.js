const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PorkelonPolygon", function () {
  let Porkelon, porkelon, owner, teamWallet, liquidityWallet, user1, user2;

  beforeEach(async () => {
    [owner, teamWallet, liquidityWallet, user1, user2] = await ethers.getSigners();

    Porkelon = await ethers.getContractFactory("PorkelonPolygon");
    porkelon = await Porkelon.deploy(teamWallet.address, liquidityWallet.address);
    await porkelon.deployed();
  });

  it("Should deploy with correct name, symbol, and supply", async () => {
    expect(await porkelon.name()).to.equal("Porkelon");
    expect(await porkelon.symbol()).to.equal("PORK");
    expect(await porkelon.totalSupply()).to.equal(ethers.utils.parseUnits("100000000000", 18));
  });

  it("Should lock team and liquidity tokens for 365 days", async () => {
    const [teamAmount, releaseTeam, claimedTeam] = await porkelon.teamLockedInfo();
    const [liqAmount, releaseLiq, claimedLiq] = await porkelon.liquidityLockedInfo();

    expect(teamAmount).to.equal(ethers.utils.parseUnits("20000000000", 18)); // 20%
    expect(liqAmount).to.equal(ethers.utils.parseUnits("40000000000", 18)); // 40%
    expect(claimedTeam).to.equal(false);
    expect(claimedLiq).to.equal(false);

    // Can't claim before unlock
    await expect(porkelon.connect(teamWallet).claimTeamTokens()).to.be.revertedWith("team locked");
    await expect(porkelon.connect(liquidityWallet).claimLiquidityTokens()).to.be.revertedWith("liquidity locked");
  });

  it("Should allow owner to set presale price and sell tokens", async () => {
    const presalePrice = ethers.utils.parseEther("0.000000001"); // 1 wei per token
    await porkelon.setPresalePrice(presalePrice);

    const buyAmount = ethers.utils.parseUnits("1000", 18);
    const weiRequired = buyAmount.mul(presalePrice).div(ethers.utils.parseUnits("1", 18));

    await expect(() =>
      porkelon.connect(user1).buyPresale(buyAmount, { value: weiRequired })
    ).to.changeTokenBalances(porkelon, [porkelon, user1], [buyAmount.mul(-1), buyAmount]);
  });

  it("Should perform an airdrop batch", async () => {
    const amounts = [
      ethers.utils.parseUnits("100", 18),
      ethers.utils.parseUnits("200", 18),
    ];
    await porkelon.airdropBatch([user1.address, user2.address], amounts);

    expect(await porkelon.balanceOf(user1.address)).to.equal(amounts[0]);
    expect(await porkelon.balanceOf(user2.address)).to.equal(amounts[1]);
  });

  it("Should allow staking and reward distribution", async () => {
    const stakeAmount = ethers.utils.parseUnits("1000", 18);

    // Transfer some staking tokens to user
    await porkelon.airdropBatch([user1.address], [stakeAmount]);

    await porkelon.connect(user1).stake(stakeAmount);

    expect(await porkelon.balancesStaked(user1.address)).to.equal(stakeAmount);

    // Fund rewards
    const rewardAmount = ethers.utils.parseUnits("100", 18);
    await porkelon.topUpRewardsPool(rewardAmount);

    // Notify rewards distribution over 10 seconds
    await porkelon.notifyRewardAmount(rewardAmount, 10);

    // Fast forward 10 seconds
    await ethers.provider.send("evm_increaseTime", [10]);
    await ethers.provider.send("evm_mine");

    await porkelon.connect(user1).getReward();
    const bal = await porkelon.balanceOf(user1.address);

    expect(bal).to.be.gt(0); // got some rewards
  });
});
