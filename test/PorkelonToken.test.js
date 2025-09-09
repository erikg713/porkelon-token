const { expect } = require("chai");
const { ethers } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

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
describe("PorkelonToken", function () {
  let owner, alice, marketing, spender;
  let Token, token;

  // Helpers to support both ethers v5 (BigNumber) and v6 (bigint)
  const toBigInt = (value) => {
    if (typeof value === "bigint") return value;
    if (value === null || value === undefined) return null;
    // ethers v5 BigNumber / BN-like objects support toString()
    if (typeof value.toString === "function") return BigInt(value.toString());
    // fallback
    return BigInt(value);
  };

  const parseUnits = (value, decimals = 18) => {
    // ethers v6 exposes parseUnits at top level, v5 under utils
    if (typeof ethers.parseUnits === "function") return ethers.parseUnits(value, decimals);
    return ethers.utils.parseUnits(value, decimals);
  };

  const computeOnePercent = (amountBigInt) => {
    return amountBigInt / 100n; // integer division; matches typical on-chain truncation
  };

  // A small wrapper for readable assertions that will accept BigInt or BigNumber inputs
  const expectEqualNumeric = (actual, expected, message) => {
    const a = toBigInt(actual);
    const e = toBigInt(expected);
    expect(a, message).to.equal(e);
  };

  beforeEach(async function () {
    [owner, alice, marketing, spender] = await ethers.getSigners();
    Token = await ethers.getContractFactory("PorkelonToken");
    token = await Token.deploy(marketing.address);
    await token.deployed();
  });

  it("applies 1% fee on direct transfers", async function () {
    const amount = parseUnits("1000", 18);
    const amountBI = toBigInt(amount);

    // owner transfers tokens to alice
    await token.transfer(alice.address, amount);

    const marketingBal = await token.balanceOf(marketing.address);
    const aliceBal = await token.balanceOf(alice.address);

    const expectedFee = computeOnePercent(amountBI);
    const expectedAlice = amountBI - expectedFee;

    expectEqualNumeric(marketingBal, expectedFee, "marketing should receive 1% fee");
    expectEqualNumeric(aliceBal, expectedAlice, "recipient should receive amount minus 1% fee");
  });

  it("applies 1% fee on transferFrom (approved spender) and consumes allowance", async function () {
    const amount = parseUnits("250.5", 18); // test fractional token amounts
    const amountBI = toBigInt(amount);

    // owner approves spender to move tokens on their behalf
    await token.approve(spender.address, amount);
    // spender performs transferFrom to move owner's tokens to alice
    await token.connect(spender).transferFrom(owner.address, alice.address, amount);

    const marketingBal = await token.balanceOf(marketing.address);
    const aliceBal = await token.balanceOf(alice.address);
    const allowanceAfter = await token.allowance(owner.address, spender.address);

    const expectedFee = computeOnePercent(amountBI);
    const expectedAlice = amountBI - expectedFee;

    expectEqualNumeric(marketingBal, expectedFee, "marketing should receive 1% fee on transferFrom");
    expectEqualNumeric(aliceBal, expectedAlice, "recipient should receive amount minus 1% fee on transferFrom");
    expectEqualNumeric(allowanceAfter, 0n, "allowance should be consumed by transferFrom");
  });

  it("handles very small transfers and rounding consistently", async function () {
    // Transfer exactly 1 token (with 18 decimals) -> fee should be 0.01 token (1e16)
    const amount = parseUnits("1", 18);
    const amountBI = toBigInt(amount);

    await token.transfer(alice.address, amount);

    const marketingBal = await token.balanceOf(marketing.address);
    const aliceBal = await token.balanceOf(alice.address);

    const expectedFee = computeOnePercent(amountBI);
    const expectedAlice = amountBI - expectedFee;

    expectEqualNumeric(marketingBal, expectedFee, "marketing should receive correct fee for 1 token");
    expectEqualNumeric(aliceBal, expectedAlice, "alice should receive correct net amount for 1 token");
  });

  it("does not charge a fee on zero-value transfers", async function () {
    // Zero transfers should be no-ops and not change balances
    const zero = parseUnits("0", 18);
    const ownerBalBefore = await token.balanceOf(owner.address);
    const marketingBalBefore = await token.balanceOf(marketing.address);

    await token.transfer(alice.address, zero);

    const ownerBalAfter = await token.balanceOf(owner.address);
    const marketingBalAfter = await token.balanceOf(marketing.address);

    expectEqualNumeric(ownerBalAfter, ownerBalBefore, "owner balance unchanged after zero transfer");
    expectEqualNumeric(marketingBalAfter, marketingBalBefore, "marketing balance unchanged after zero transfer");
  });
});
