const { ethers, upgrades } = require('hardhat');

async function main() {
  const [deployer] = await ethers.getSigners();
  const ADMIN_ADDRESS = '0xYourAdminWallet';
  const BRIDGE_OPERATOR = '0xYourBridgeWallet';
  const MIGRATION_VAULT = '0xYourVaultWallet';
  const UNISWAP_ROUTER = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45'; // QuickSwap

  console.log('Deploying with:', deployer.address);

  // Deploy Timelock
  const Timelock = await ethers.getContractFactory('PorkelonTimelock');
  const timelock = await Timelock.deploy(2 * 24 * 60 * 60, [ADMIN_ADDRESS], [ADMIN_ADDRESS], ADMIN_ADDRESS); // 48 hours
  await timelock.waitForDeployment();
  console.log('Timelock deployed to:', timelock.target);

  // Deploy Porkelon (proxy)
  const Porkelon = await ethers.getContractFactory('Porkelon');
  const porkelon = await upgrades.deployProxy(Porkelon, [ADMIN_ADDRESS], {
    initializer: 'initialize',
    kind: 'transparent',
    admin: timelock.target,
  });
  await porkelon.waitForDeployment();
  console.log('Porkelon deployed to:', porkelon.target);

  // Deploy Presale
  const Presale = await ethers.getContractFactory('Presale');
  const presale = await Presale.deploy(porkelon.target);
  await presale.waitForDeployment();
  console.log('Presale deployed to:', presale.target);

  // Transfer presale tokens
  await porkelon.transfer(presale.target, ethers.parseEther('40000000000'));
  console.log('Transferred 40B $PORK to presale');

  // Deploy Staking
  const Staking = await ethers.getContractFactory('Staking');
  const staking = await Staking.deploy(porkelon.target, MIGRATION_VAULT);
  await staking.waitForDeployment();
  console.log('Staking deployed to:', staking.target);

  // Deploy Liquidity
  const Liquidity = await ethers.getContractFactory('Liquidity');
  const liquidity = await Liquidity.deploy(porkelon.target, UNISWAP_ROUTER);
  await liquidity.waitForDeployment();
  console.log('Liquidity deployed to:', liquidity.target);

  // Transfer ownership to timelock
  await porkelon.transferOwnership(timelock.target);
  await presale.transferOwnership(timelock.target);
  await staking.transferOwnership(timelock.target);
  await liquidity.transferOwnership(timelock.target);
  console.log('Ownership transferred to timelock');

  console.log('Update constants.ts with:');
  console.log(`ADMIN_ADDRESS: "${ADMIN_ADDRESS}"`);
  console.log(`BRIDGE_OPERATOR: "${BRIDGE_OPERATOR}"`);
  console.log(`MIGRATION_VAULT: "${MIGRATION_VAULT}"`);
  console.log(`PRESALE_CONTRACT: "${presale.target}"`);
  console.log(`TOKEN_CONTRACT: "${porkelon.target}"`);
  console.log(`STAKING_CON
