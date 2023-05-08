const ZNSDomain = artifacts.require("ZNSDomain");
const ZNSRegistrar = artifacts.require("ZNSRegistrar");
const ZNSStaking = artifacts.require("ZNSStaking");
const ZEROToken = artifacts.require("ZEROToken");

module.exports = async function (deployer, network, accounts) {
  // Deploy the ZNSDomain contract
  await deployer.deploy(ZNSDomain);
  const znsDomain = await ZNSDomain.deployed();

  // Deploy the ZEROToken contract
  await deployer.deploy(ZEROToken);
  const zeroToken = await ZEROToken.deployed();

  // Initialize the ZEROToken contract
  await zeroToken.initialize("ZERO TOKEN", "ZERO");

  // Mint tokens to a specific address
  const recipientAddress = '0xdE0C2ddd5e5f2C1eAB6730933b301692d98a8B80';
  await zeroToken.mint(recipientAddress, 1000000000000000);

  // Deploy the ZNSStaking contract
  await deployer.deploy(ZNSStaking, znsDomain.address, zeroToken.address);
  const znsStaking = await ZNSStaking.deployed();

  // Deploy the ZNSRegistrar contract
  await deployer.deploy(ZNSRegistrar);
  const znsRegistrar = await ZNSRegistrar.deployed();

  // Initialize the ZNSRegistrar contract with the required parameters
  const DOMAIN_COST = 1000;
  await znsRegistrar.initialize(
    znsDomain.address,
    zeroToken.address,
    znsStaking.address,
    DOMAIN_COST
  );
};
