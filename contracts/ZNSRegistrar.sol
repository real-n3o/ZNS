/**
  @title ZNSRegistrar
  @dev Contract for registering and updating ZNS domains
  @notice This contract allows users to register Zero Name Service (ZNS) domains
  @notice A ZNS domain is an ERC721 NFT token with a URI
  @notice Each domain costs a specified amount of Zero Tokens
  SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ZNSDomain.sol";
import "./ZNSStaking.sol";

contract ZNSRegistrar is Initializable, ReentrancyGuardUpgradeable {
  using SafeMathUpgradeable for uint256;
  uint256 public domainCost;
  ZNSDomain public znsDomain;
  IERC20Upgradeable public zeroToken;
  ZNSStaking public znsStaking;
  bool public initialized;

  // To Do: + resolver contract to struct
  // To Do: + subdomainRegistrar contract to struct

  /**
   * @dev Stores information about a registered domain.
   * @param tokenId The token ID of the NFT representing the domain.
   * @param tokenURI The metadata URI of the NFT representing the domain.
  */
  struct Domain {
    uint256 tokenId;
    string tokenURI;
  }

  mapping(string => Domain) private _domains;
  mapping(uint256 => string) private _tokenIdsToDomains;

  /**
    @dev Event emitted when a domain is minted
    @param tokenId The ID of the minted domain
    @param domainName The name of the minted domain
    @param owner The address of the domain owner
  */
  event DomainMinted(uint256 indexed tokenId, string indexed domainName, address indexed owner);

  /**
    * @dev Emitted when the token URI of a domain is updated.
    * @param tokenId The ID of the domain that had its token URI updated.
    * @param oldTokenURI The old token URI of the domain.
    * @param newTokenURI The new token URI of the domain.
  */
  event TokenURIUpdated(uint256 indexed tokenId, string oldTokenURI, string newTokenURI);

  /**
    * @dev Emitted when the cost of a domain is set.
    * @param newDomainCost The new cost of a domain.
    */
  event DomainCostSet(uint256 newDomainCost);

  /**
    @dev Initializes the ZNSRegistrar contract
    @param _znsDomain The address of the ZNSDomain contract
    @param _zeroToken The address of the ZEROToken contract
    @param _znsStaking The address of the ZNSStaking contract
    @param _domainCost The cost of registering a domain in Zero Tokens
  */
  function initialize(ZNSDomain _znsDomain, IERC20Upgradeable _zeroToken, ZNSStaking _znsStaking, uint256 _domainCost) public initializer {
    require(!initialized, "ZNSRegistrar: Contract is already initialized");
    __ReentrancyGuard_init();
    __ZNSRegistrar_init(_znsDomain, _zeroToken, _znsStaking, _domainCost);
  }

  /**
    * @dev Emitted when a domain is destroyed.
    * @param tokenId The ID of the destroyed domain.
    * @param domainName The name of the destroyed domain.
  */
  event DomainDestroyed(uint256 indexed tokenId, string domainName);

  function __ZNSRegistrar_init(ZNSDomain _znsDomain, IERC20Upgradeable _zeroToken, ZNSStaking _znsStaking, uint256 _domainCost) internal {
    znsDomain = _znsDomain;
    zeroToken = _zeroToken;        
    znsStaking = _znsStaking;
    domainCost = _domainCost;
    initialized = true;
  }

  /**
    @dev Mints a new domain
    @param domainName The name of the domain to be minted
    @param tokenURI The URI of the domain token
  */
  function mintDomain(string memory domainName, string memory tokenURI) public nonReentrant {
    require(zeroToken.balanceOf(msg.sender) >= domainCost, "ZNSRegistrar: Insufficient Zero Token balance");
    require(zeroToken.allowance(msg.sender, address(this)) >= domainCost, "ZNSRegistrar: Token allowance not sufficient");

    // Check if the domain name already exists
    Domain storage existingDomain = _domains[domainName];
    require(existingDomain.tokenId == 0, "ZNSRegistrar: Domain name already exists with tokenId ");

    // Ensure that the staking contract address is valid
    require(address(znsStaking) != address(0), "ZNSRegistrar: Invalid staking contract address");

    // Transfer tokens from sender directly to staking contract using SafeERC20
    SafeERC20Upgradeable.safeTransferFrom(zeroToken, msg.sender, address(znsStaking), domainCost);

    // Mint the domain
    uint256 newDomainId = znsDomain.mintDomain(msg.sender, tokenURI);
    znsDomain.setTokenURI(newDomainId, tokenURI);
    _domains[domainName] = Domain(newDomainId, tokenURI);

    // Store mapping between token ID and domain name
    _tokenIdsToDomains[newDomainId] = domainName;

    // Add stake
    znsStaking.addStake(newDomainId, domainCost, msg.sender);

    emit DomainMinted(newDomainId, domainName, msg.sender);
  }

  /**
    * @dev Destroys a domain.
    * @param tokenId The ID of the domain to be destroyed.
  */
  function destroyDomain(uint256 tokenId) public {
    // Look up domain name by token ID
    string memory domainName = _tokenIdsToDomains[tokenId];

    // Check if the sender is the owner of the domain
    require(znsDomain.ownerOf(tokenId) == msg.sender, "Only the domain owner can withdraw staked tokens");

    // Withdraw the stake
    znsStaking.withdrawStake(tokenId, msg.sender);

    // Delete the domain from the _domains mapping
    delete _domains[domainName];

    // Delete the mapping between token ID and domain name
    delete _tokenIdsToDomains[tokenId];

    // Burn the domain
    znsDomain.burn(tokenId, msg.sender);

    // Emit the event
    emit DomainDestroyed(tokenId, domainName);
  }

  /**
    * @dev Gets the token ID associated with the given domain name.
    * @param domainName The name of the domain to get the token ID for.
    * @return The token ID of the domain.
  */
  function domainNameToTokenId(string memory domainName) public view returns (uint256) {
    require(_domains[domainName].tokenId != 0, "ZNSRegistrar: Domain name does not exist");
    return _domains[domainName].tokenId;
  }

  /**
    * @dev Gets the token URI associated with the given domain name.
    * @param domainName The name of the domain to get the token URI for.
    * @return The token URI of the domain.
  */
  function domainNameToTokenURI(string memory domainName) public view returns (string memory) {
    require(_domains[domainName].tokenId != 0, "ZNSRegistrar: Domain name does not exist");
    return _domains[domainName].tokenURI;
  }

  /**
    * @dev Updates the token URI of a given domain.
    * @param tokenId The ID of the domain to update the token URI of.
    * @param newTokenURI The new token URI for the domain.
  */
  function updateTokenURI(uint256 tokenId, string calldata newTokenURI) external {
    // Check if the sender is the owner of the domain
    require(znsDomain.ownerOf(tokenId) == msg.sender, "Caller is not the owner of the domain");

    // Get the old token URI
    string memory oldTokenURI = znsDomain.tokenURI(tokenId);

    // Update the token URI
    znsDomain.setTokenURI(tokenId, newTokenURI);

    // Emit the event
    emit TokenURIUpdated(tokenId, oldTokenURI, newTokenURI);
  }

  // To Do: Possibly offload to a separate pricing contract for upgradeability/modularity
  
  /**
    * @dev Sets the cost of a domain.
    * @param _newDomainCost The new cost for a domain.
  */
  function setDomainCost(uint256 _newDomainCost) public {
    domainCost = _newDomainCost;
    emit DomainCostSet(_newDomainCost);
  }

  /**
    * @dev Checks to see whether or not a domainis is available.
    * @param domainName The domain to check.
    * @return bool
  */
  function isDomainAvailable(string memory domainName) public view returns (bool) {
    return _domains[domainName].tokenId == 0;
  }

  uint256[49] private __gap;
}