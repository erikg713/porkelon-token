const { expect } = require("chai");

describe("PorkelonToken", function () {
  it("applies 1% fee on transfers", async function () {
    const [owner, alice, marketing] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("PorkelonToken");
    const token = await Token.deploy(marketing.address);
    await token.deployed();

    const amount = ethers.parseUnits("1000", 18);
    await token.transfer(alice.address, amount);

    const marketingBal = await token.balanceOf(marketing.address);
    expect(marketingBal).to.equal(ethers.parseUnits("10", 18)); // 1%

    const aliceBal = await token.balanceOf(alice.address);
    expect(aliceBal).to.equal(ethers.parseUnits("990", 18));
  });
});
