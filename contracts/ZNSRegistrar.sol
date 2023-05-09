/**
  @title ZNSRegistrar
  @dev Contract for registering and updating ZNS domains
  @notice This contract allows users to register Zero Name Service (ZNS) domains
  @notice A ZNS domain is an ERC721 NFT token with a URI
  @notice Each domain costs a specified amount of Zero Tokens
  SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.0;

// Overall, the ZNS system is designed in a similar way to what we have,
// but is still missing important parts like domain resolvers,
// where a domain content is tied to the domain name and token. It is also
// missing a good connection between contracts and some integrity based in the
// way certain flows are written. There's now way to easily improve pricing
// strategies without significant code and storage changes, requiring an on-chain upgrade.
// Addition of these modules will trigger changes in the way data is stored currently.
// Some of the flows are inefficiently split between modules in a way where responsibility
// is not always clear.

// In this system design the base settlement storage is located on the Token contract,
// which makes it a form of Registry combined with the Token functionality,
// which may prove to be hard to maintain over long-term. Any changes required to the way
// data is stored or managed will require a full-on upgrade of the token contract, which is not
// a good strategy. Ideally, the token code should be only related to tokens,
// and system storage being separate, so that changes to the system require minimal changes
// for the token code. It may not be possible to avoid touching token code at all,
// but possible changes should be minimized at the design stage.
// Upgrading token code on-chain is one of the most dangerous and risky operations for web3 apps,
// so if possible, it should be avoided.

// The system so far has no notion of Access Control and can very easily be exploited,
// by breaking down flows that need to be atomic into pieces creating multiple discrepancies in the system
// data and the way it operates.
// Access control will bring complexity and possibly more storage changes.
// Integer IDs and strings are used to indetify domains, which do not provide
// a convenient way of dealing with SC data off-chain and on the contracts, strings also
// make many operations more expensive and harder to maintain over the long term.
// IMO hashes should be used to identify domains, and tokenIDs should be derived from hashes,
// negating the need for additional storage to bind those together.
// Simple integer IDs for domains can also cause all sorts of errors and improper testing
// because these values can be easily misread or confused with any other number value,
// making certain tests not catch possible errors.
// Number IDs are also very easy to find or calculate for any attack strategy, if applicable.

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ZNSDomain.sol";
import "./ZNSStaking.sol";

contract ZNSRegistrar is Initializable, ReentrancyGuardUpgradeable {
  using SafeMathUpgradeable for uint256;
  // if any changes to pricing model are needed later with upgrades and storage changes,
  // this state slot will be dead forever, which is not a big deal, but should be considered
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
  // by using domain hashes and tokenID created from those + native ERC721 tokenURI management
  // we can avoid this storage structure altogether along with the mapping below
  struct Domain {
    uint256 tokenId;
    string tokenURI;
  }

  // using strings on contracts in this way is not the best idea
  // string are all different lengths and can be very long
  // + clashes between names might be possible depending on the
  // encoding table used. also working with strings is harder and more
  // gas comsuming in Solidity. bytes is a preferred method.
  // is this a string for a full domain address or just the last level name?
  // can we differentiate the level of domain from this string?
  mapping(string => Domain) private _domains;
  // this can be avoided as well by using the domain hash casted into uint256 as the tokenID
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
    // the `initializer` modifier ensures this function can only be called once
    // so this is not necessary
    require(!initialized, "ZNSRegistrar: Contract is already initialized");
    // this contract can be avoided to save on deploy costs
    // if the code in state updating functions is written properly
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
    // no addresses are checked
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
    // not a necessary gas cost addition here, since `transfer()` functions will revert if insufficient balance
    require(zeroToken.balanceOf(msg.sender) >= domainCost, "ZNSRegistrar: Insufficient Zero Token balance");
    // same here, functions in the standard check this already
    require(zeroToken.allowance(msg.sender, address(this)) >= domainCost, "ZNSRegistrar: Token allowance not sufficient");

    // Check if the domain name already exists
    // instead of reading the whole struct, which is 2 slots,
    // we can just read only tokenID field and save half of the gas
    Domain storage existingDomain = _domains[domainName];
    require(existingDomain.tokenId == 0, "ZNSRegistrar: Domain name already exists with tokenId ");

    // Ensure that the staking contract address is valid
    // this should be checked once when this state var is set in storage
    // here it will impose unnecessary extra gas costs for every single transaction
    // we are paying for a state read + check here
    require(address(znsStaking) != address(0), "ZNSRegistrar: Invalid staking contract address");

    // Transfer tokens from sender directly to staking contract using SafeERC20
    // imo Staking contract should do this along with updating it's state
    SafeERC20Upgradeable.safeTransferFrom(zeroToken, msg.sender, address(znsStaking), domainCost);

    // Mint the domain
    // why do we need both of the below calls? we should be able to do this in one
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
    // delete first, update all storage, then withdraw
    // otherwise we are open to reentrancy attacks
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
    // no need for this check. it doesn't hurt, but if we use this in the contract code,
    // we will pay extra gas for this check
    // in the case of token not existing it should just return zero
    require(_domains[domainName].tokenId != 0, "ZNSRegistrar: Domain name does not exist");
    return _domains[domainName].tokenId;
  }

  /**
    * @dev Gets the token URI associated with the given domain name.
    * @param domainName The name of the domain to get the token URI for.
    * @return The token URI of the domain.
  */
  function domainNameToTokenURI(string memory domainName) public view returns (string memory) {
    // same here. not necessary
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

    // tokenURI is not updated anywhere on this contract's storage
    // creating discrepancy in the system

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
  // the function is here, but not used by anything on this contract.
  // there can be a case made to make an internal function + external view function
  // the external will use the internal one under the hood + the internal can be used
  // in many checks on this contract instead of statements
  // making it easier to maintain, by changing just one thing, instead of looking for individual
  // checks in all functions where they appear
  function isDomainAvailable(string memory domainName) public view returns (bool) {
    return _domains[domainName].tokenId == 0;
  }

  uint256[49] private __gap;
}