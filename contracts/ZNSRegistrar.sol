/**
  @title ZNSRegistrar
  @dev Contract for registering and updating ZNS domains
  @notice This contract allows users to register Zero Name Service (ZNS) domains
  @notice A ZNS domain is an ERC721 NFT token with a URI
  @notice Each domain costs a specified amount of Zero Tokens
  SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.0;

//  * It is also missing a good connection between contracts and some integrity based in the
// way certain flows are written. 

// * There's now way to easily improve pricing strategies without significant code and storage changes, 
// requiring an on-chain upgrade. Addition of these modules will trigger changes in the way data is stored currently.
// Some of the flows are inefficiently split between modules in a way where responsibility is not always clear.

// In this system design the base settlement storage is located on the Token contract,
// which makes it a form of Registry combined with the Token functionality,
// which may prove to be hard to maintain over long-term. 

// * Any changes required to the way data is stored or managed will require a full-on upgrade of the token contract, 
// which is not a good strategy. Ideally, the token code should be only related to tokens,
// and system storage being separate, so that changes to the system require minimal changes
// for the token code.

// * The system so far has no notion of Access Control and can very easily be exploited,
// by breaking down flows that need to be atomic into pieces creating multiple discrepancies in the system
// data and the way it operates. Access control will bring complexity and possibly more storage changes.

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { ZNSDomain } from "./ZNSDomain.sol";
import { ZNSStaking } from "./ZNSStaking.sol";
import { ZEROToken } from "./ZEROToken.sol";

contract ZNSRegistrar is Initializable, ReentrancyGuardUpgradeable {
  using SafeMathUpgradeable for uint256;
  // if any changes to pricing model are needed later with upgrades and storage changes,
  // this state slot will be dead forever, which is not a big deal, but should be considered
  uint256 public domainCost;
  ZNSDomain public znsDomain;
  ZEROToken public zeroToken;
  ZNSStaking public znsStaking;

  /**
   * @dev Stores information about a registered domain.
   * @param tokenId The token ID of the NFT representing the domain.
  */
  struct Domain {
    uint256 tokenId; // using domain hashes we can avoid this storage here
    address domainAddress; // To Do: + domain contract getters/setters
    address resolverAddress; // To Do: + resolver contract getters/setters
  }

  // [ FIX ]
  // using strings on contracts in this way is not the best idea
  // string are all different lengths and can be very long
  // + clashes between names might be possible depending on the
  // encoding table used. also working with strings is harder and more
  // gas comsuming in Solidity. bytes is a preferred method.
  // is this a string for a full domain address or just the last level name?
  // can we differentiate the level of domain from this string?
  mapping(string => Domain) private _domains;

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
  function initialize(ZNSDomain _znsDomain, ZEROToken _zeroToken, ZNSStaking _znsStaking, uint256 _domainCost) public initializer {
    // [Discuss]
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

  function __ZNSRegistrar_init(ZNSDomain _znsDomain, ZEROToken _zeroToken, ZNSStaking _znsStaking, uint256 _domainCost) internal {
    // Check that the addresses are not the zero address
    require(_znsDomain != ZNSDomain(address(0)), "Invalid ZNSDomain address");
    require(_zeroToken != ZEROToken(address(0)), "Invalid ZeroToken address");
    require(_znsStaking != ZNSStaking(address(0)), "Invalid ZNSStaking address");
    
    znsDomain = _znsDomain;
    zeroToken = _zeroToken;
    znsStaking = _znsStaking;
    domainCost = _domainCost;
  }

  /**
    @dev Mints a new domain
    @param domainName The name of the domain to be minted
  */
  function mintDomain(string memory domainName) public nonReentrant {
    // Check if the domain name already exists
    uint256 existingDomainId = _domains[domainName].tokenId;
    require(existingDomainId == 0, "ZNSRegistrar: Domain name already exists with tokenId ");

    // Mint the domain
    uint256 newDomainId = znsDomain.mintDomain(msg.sender);
    _domains[domainName] = Domain(newDomainId, address(0), address(0));

    // Add stake
    znsStaking.addStake(newDomainId, domainCost);

    emit DomainMinted(newDomainId, domainName, msg.sender);
  }

  /**
    * @dev Destroys a domain.
    * @param domainName The ID of the domain to be destroyed.
  */
  function destroyDomain(string calldata domainName) public {
    // Check if the sender is the owner of the domain
    uint256 tokenId = _domains[domainName].tokenId;
    require(znsDomain.ownerOf(tokenId) == msg.sender, "Only the domain owner can withdraw staked tokens");

    // Delete, burn and withdraw the stake
    delete _domains[domainName];
    znsStaking.withdrawStake(tokenId);
    znsDomain.burn(tokenId, msg.sender);
    // NOTE: May need to move this into ZNSStaking contract but need to determine AC

    // Emit the event
    emit DomainDestroyed(tokenId, domainName);
  }

  /**
    * @dev Gets the token ID associated with the given domain name.
    * @param domainName The name of the domain to get the token ID for.
    * @return The token ID of the domain.
  */
  function domainNameToTokenId(string memory domainName) public view returns (uint256) {
    return _domains[domainName].tokenId;
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
  // [Discuss]
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