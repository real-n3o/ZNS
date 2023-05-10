const ZNSDomain = artifacts.require("ZNSDomain");
const ZNSRegistrar = artifacts.require("ZNSRegistrar");
const ZNSStaking = artifacts.require("ZNSStaking");
const ZEROToken = artifacts.require("ZEROToken");

const BN = require("bn.js");

const web3 = require('web3');
const { expectRevert } = require('@openzeppelin/test-helpers');

contract("ZNSRegistrar", accounts => {
  let znsDomain, zeroToken, znsStaking, znsRegistrar;

  // Initialize primary test parameters
  const DOMAIN_COST = 1000;
  const DOMAIN_NAME = "mydomain";
  const DOMAIN_URI = "https://mydomain.com";
  const DOMAIN_NAME_1 = "myotherdomain";
  const DOMAIN_URI_1 = "https://myotherdomain.com";
  const DOMAIN_NAME_2 = "myotherdomainmeow";
  const DOMAIN_URI_2 = "https://myotherdomainmeow.com";

  beforeEach(async () => {
    // Deploy core contracts
    znsDomain = await ZNSDomain.new();
    zeroToken = await ZEROToken.new();
    znsStaking = await ZNSStaking.new();
    znsRegistrar = await ZNSRegistrar.new();

    // Initialize contracts
    zeroToken.initialize(
      "ZERO TOKEN",
      "ZERO"
    );
    await zeroToken.mint(accounts[0], 1000000000000000);
    await znsDomain.initialize();
    await znsStaking.initialize(
      znsDomain.address, 
      zeroToken.address
    );
    await znsRegistrar.initialize(
      znsDomain.address, 
      zeroToken.address, 
      znsStaking.address, 
      DOMAIN_COST
    );   
  });

  it("should have valid Ethereum addresses for znsDomain, znsRegistrar, znsStaking and zeroToken", async () => {
    assert.isTrue(web3.utils.isAddress(znsDomain.address), "znsDomain should have a valid Ethereum address");
    assert.isTrue(web3.utils.isAddress(znsRegistrar.address), "znsRegistrar should have a valid Ethereum address");
    assert.isTrue(web3.utils.isAddress(znsStaking.address), "zeroToken should have a valid Ethereum address");
    assert.isTrue(web3.utils.isAddress(zeroToken.address), "zeroToken should have a valid Ethereum address");
  });

  it("should have the correct name and symbol for the ZNSDomain contract", async () => {
    const name = await znsDomain.name();
    const symbol = await znsDomain.symbol();
  
    assert.equal(name, "Zero Name Service (ZNS)", "ZNSDomain contract should have the correct name");
    assert.equal(symbol, "ZNS", "ZNSDomain contract should have the correct symbol");
  });

  it("should mint a domain and confirm tokenId were set correctly", async () => {
    const domainCost = await znsRegistrar.domainCost();
    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME, { from: accounts[0] });
    
    const tokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME);
    assert.equal(tokenId.toNumber(), 1, "Domain name should map to the correct token ID");

    const owner = await znsDomain.ownerOf(tokenId);
    assert.equal(owner, accounts[0], "Domain owner should be the first account");

    const totalSupply = await znsDomain.totalSupply();
    assert.equal(totalSupply.toNumber(), 1, "Total supply should be increased by 1");
});

  it("destroy domain and confirm stake was returned to owner", async () => {
    // Mint a domain
    const domainCost = await znsRegistrar.domainCost();
    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME, { from: accounts[0] });

    // Check that supply has been updated correctly
    const totalSupplyAfterMint = await znsDomain.totalSupply();
    assert.equal(totalSupplyAfterMint.toNumber(), 1, "Total supply should be increased by 1");

    // Get the newly created domain id
    const domainId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME);
    
    // Check that the domain exists
    assert.notEqual(domainId, 0, "Domain does not exist");
  
    const balanceBefore = await zeroToken.balanceOf.call(accounts[0]);
  
    // Get domain tokenID
    const tokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME);

    // Destroy the domain
    await znsRegistrar.destroyDomain(tokenId, { from: accounts[0] });
  
    // Check that the tokens were returned to the owner
    const balanceAfter = await zeroToken.balanceOf.call(accounts[0]);
    assert(balanceAfter.sub(balanceBefore), DOMAIN_COST, "Tokens were not returned to owner");
  
    // Check that the domain no longer exists
    const destroyedTokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME);
    assert.strictEqual(destroyedTokenId.eq(new BN(0)), true);

    // Check that supply has been updated correctly
    const totalSupplyAfterBurn = await znsDomain.totalSupply();
    assert.equal(totalSupplyAfterBurn.toNumber(), 0, "Total supply should be decreased by 1");
  });

  it("should mint a second domain and confirm tokenId were set correctly", async () => {
    const domainCost = await znsRegistrar.domainCost();
    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME_1, { from: accounts[0] });
    
    const tokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME_1);
    assert.equal(tokenId.toNumber(), 1, "Domain name should map to the correct token ID");

    const owner = await znsDomain.ownerOf(1);
    assert.equal(owner, accounts[0], "Domain owner should be the first account");

    const totalSupply = await znsDomain.totalSupply();
    assert.equal(totalSupply.toNumber(), 1, "Total supply should be increased by 1");
  });

  it("should set/get proper domain id for when multiple domains are minted", async () => {
    const domainCost = await znsRegistrar.domainCost();
    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME, { from: accounts[0] });
    
    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME_1, { from: accounts[0] });

    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME_2, { from: accounts[0] });

    const tokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME_2);
    assert.equal(tokenId.toNumber(), 3, "Domain name should map to the correct token ID");

    const totalSupply = await znsDomain.totalSupply();
    assert.equal(totalSupply.toNumber(), 3, "Total supply should be 3");
  });

  it("should transfer domain ownership from existing to new owner", async () => {
    // Mint the domain
    const domainCost = await znsRegistrar.domainCost();
    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME, { from: accounts[0] });

    // Get the tokenId
    const tokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME);

    // Transfer the domain
    await znsDomain.safeTransferFrom(accounts[0], accounts[1], tokenId, { from: accounts[0] });

    // Confirm the new owner
    const newOwner = await znsDomain.ownerOf(tokenId);
    assert.equal(newOwner, accounts[1], "Domain owner should be the second account");
  });

  it("should set a new cost in ZERO for all domains", async () => {
    // Set a new domain cost
    const NEW_DOMAIN_COST = 2000;
    await znsRegistrar.setDomainCost(NEW_DOMAIN_COST);

    // Retrieve the updated domain cost
    const updatedDomainCost = await znsRegistrar.domainCost.call();

    // Check if the new domain cost is set correctly
    assert.equal(updatedDomainCost.toNumber(), NEW_DOMAIN_COST, "Domain cost should be updated to the new value");

    // Mint a domain with the new domain cost
    await zeroToken.approve(znsStaking.address, updatedDomainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME, { from: accounts[0] });

    // Confirm the domain was minted
    const tokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME);
    assert.equal(tokenId.toNumber(), 1, "Domain name should map to the correct token ID");
  });

  // it("should update the tokenURI after a domain has been minted", async () => {
  //   // Mint a domain
  //   await zeroToken.approve(znsRegistrar.address, DOMAIN_COST, { from: accounts[0] });
  //   await znsRegistrar.mintDomain(DOMAIN_NAME);

  //   // Update the tokenURI
  //   const NEW_DOMAIN_URI = "https://newdomain.com";
  //   const tokenId = await znsRegistrar.domainNameToTokenId(DOMAIN_NAME);
  //   await znsRegistrar.updateTokenURI(tokenId, NEW_DOMAIN_URI);

  //   // Retrieve the updated tokenURI
  //   const updatedTokenURI = await znsDomain.getTokenURI(tokenId);

  //   // Check if the new tokenURI is set correctly
  //   assert.equal(updatedTokenURI, NEW_DOMAIN_URI, "Token URI should be updated to the new value");
  // });

  it("should check to see if a domain is available", async () => {
    // Mint a domain
    const domainCost = await znsRegistrar.domainCost();
    await zeroToken.approve(znsStaking.address, domainCost, { from: accounts[0] });
    await znsRegistrar.mintDomain(DOMAIN_NAME, { from: accounts[0] });

    // Check if the domain is available
    const isAvailable = await znsRegistrar.isDomainAvailable(DOMAIN_NAME);
    assert.equal(isAvailable, false, "Domain should not be available");

    // Check if a different domain is available
    const isAvailable1 = await znsRegistrar.isDomainAvailable(DOMAIN_NAME_1);
    assert.equal(isAvailable1, true, "Domain should be available");
  });

  // upgrade domainToken contract via OZ proxy pattern

  // upgrade domainRegistrar contract via OZ proxy pattern

});