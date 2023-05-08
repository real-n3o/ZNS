// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "truffle-assertions/contracts/Assert.sol";
// import "../contracts/ZNSDomain.sol";
// import "../contracts/ZNSRegistrar.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// contract TestZNSRegistrar {
//     using SafeERC20Upgradeable for ERC20Upgradeable;
//     ZNSDomain znsDomain;
//     ZNSRegistrar znsRegistrar;
//     ERC20Upgradeable zeroToken;
//     address owner;

//     function beforeEach() public {
//         znsDomain = new ZNSDomain();
//         znsRegistrar = new ZNSRegistrar();
//         zeroToken = new ERC20Upgradeable();
//         zeroToken.initialize("Zero Token", "ZERO");
//         owner = msg.sender;

//         // Mint some tokens for the owner
//         zeroToken.mint(owner, 10000000000000000000000);

//         // Initialize the registrar and domain contracts
//         znsDomain.initialize();
//         znsRegistrar.initialize(znsDomain, zeroToken);
//     }

//     function testMintDomain() public {
//         // Mint a new domain
//         znsRegistrar.mintDomain("mydomain", "https://mydomain.com");
        
//         // Check that the domain name maps to the correct token ID
//         Assert.equal(znsRegistrar.domainNameToTokenId("mydomain"), 1, "Domain name should map to the correct token ID");

//         // Check that the domain name maps to the correct token URI
//         Assert.equal(znsRegistrar.domainNameToTokenURI("mydomain"), "https://mydomain.com", "Domain name should map to the correct token URI");
//     }

//     function testMintExistingDomain() public {
//         // Mint a new domain
//         znsRegistrar.mintDomain("mydomain", "https://mydomain.com");

//         // Try to mint the same domain again, should fail
//         (bool success, ) = address(znsRegistrar).call(abi.encodeWithSignature("mintDomain(string,string)", "mydomain", "https://mydomain.com"));
//         Assert.isFalse(success, "Should not be able to mint an existing domain");
//     }

//     function testMintDomainInsufficientBalance() public {
//         // Try to mint a domain with insufficient balance, should fail
//         (bool success, ) = address(znsRegistrar).call(abi.encodeWithSignature("mintDomain(string,string)", "mydomain", "https://mydomain.com"));
//         Assert.isFalse(success, "Should not be able to mint a domain with insufficient balance");
//     }

//     function testDomainNameToTokenIdNonexistentDomain() public {
//         // Try to get the token ID for a nonexistent domain, should fail
//         Assert.equal(znsRegistrar.domainNameToTokenId("nonexistentdomain"), 0, "Domain name should not map to a token ID");
//     }

//     function testDomainNameToTokenURINonexistentDomain() public {
//         // Try to get the token URI for a nonexistent domain, should fail
//         Assert.equal(znsRegistrar.domainNameToTokenURI("nonexistentdomain"), "", "Domain name should not map to a token URI");
//     }

//     function testDomainNameToTokenIdAndTokenURI() public {
//         // Mint a new domain
//         znsRegistrar.mintDomain("mydomain", "https://mydomain.com");

//         // Check that the domain name maps to the correct token ID and token
//     // URI
//     Assert.equal(znsRegistrar.domainNameToTokenId("mydomain"), 1, "Domain name should map to the correct token ID");
//     Assert.equal(znsRegistrar.domainNameToTokenURI("mydomain"), "https://mydomain.com", "Domain name should map to the correct token URI");

//     // Mint another domain
//     znsRegistrar.mintDomain("anotherdomain", "https://anotherdomain.com");

//     // Check that the domain name maps to the correct token ID and token URI
//     Assert.equal(znsRegistrar.domainNameToTokenId("anotherdomain"), 2, "Domain name should map to the correct token ID");
//     Assert.equal(znsRegistrar.domainNameToTokenURI("anotherdomain"), "https://anotherdomain.com", "Domain name should map to the correct token URI");
//   }
// }