const { upgrades, run } = require("hardhat");

async function main() {
  const proxy = process.env.PROXY_ADDRESS;
  if (!proxy) throw new Error("Set PROXY_ADDRESS in .env");

  const impl = await upgrades.erc1967.getImplementationAddress(proxy);
  console.log("Implementation:", impl);

  try {
    await run("verify:verify", { address: impl, constructorArguments: [] });
    console.log("Verified");
  } catch (e) {
    console.error("Verify failed:", e.message);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
