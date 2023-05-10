/**
  @title ZNSDomain
  @dev Contract for issuing ZNS domains
  SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @title ZNSDomain
 * @dev ERC721 contract for Zero Name Service (ZNS) domains.
*/
contract ZNSDomain is Initializable, ERC721Upgradeable {
  using SafeMathUpgradeable for uint256;
  using CountersUpgradeable for CountersUpgradeable.Counter;
  // using simple counter is imo not sufficient, we need to use a hash of the domain name
  // IDs as counters are easy to find and will break the sequence anyway after any domain has been revoked
  CountersUpgradeable.Counter private _domainIds;

  mapping(uint256 => string) private _tokenURIs; // not sure why this is needed, this is already accounted for in ERC721Upgradeable.sol

  /**
   * @dev Initializes the contract.
  */
  function initialize() public initializer {
    __ERC721_init("Zero Name Service (ZNS)", "ZNS");
  }

  /**
   * @dev Mint a new domain.
   * @param to The address to mint the domain to.
   * @param tokenURI The URI of the domain metadata. // why are we passing tokenUri here?
   * @return The ID of the newly minted domain.
  */
  // this functions is not protected, meaning anyone can come and mint a domain,
  // circumventing the Registrar contract and it's required flows (payments, Registrar state update, etc.)
  function mintDomain(address to, string memory tokenURI) external returns (uint256) {
    // Validate inputs
    require(to != address(0), "ZNSDomain: Invalid address");
    require(bytes(tokenURI).length > 0, "ZNSDomain: Token URI is empty");

    // Increment domain ID
    _domainIds.increment();

    // Mint new domain + set token URI
    uint256 newDomainId = _domainIds.current();
    _safeMint(to, newDomainId);
    // is there a reason we are setting URIs for tokens individually?
    // a good practice is having a base URI and then appending the token ID to it
    // do we want to keep token data in different places for the same collection?
    setTokenURI(newDomainId, tokenURI);

    return newDomainId;
  }

  /**
   * @dev Sets the URI of the domain metadata.
   * @param tokenId The ID of the domain to set the URI for.
   * @param tokenURI The new URI for the domain metadata.
  */
  function setTokenURI(uint256 tokenId, string memory tokenURI) public {
    require(_exists(tokenId), "ZNSDomain: URI set of nonexistent token");
    _tokenURIs[tokenId] = tokenURI;
  }

  /**
   * @dev Gets the URI of the domain metadata.
   * @param tokenId The ID of the domain to get the URI for.
   * @return The URI of the domain metadata.
  */
  function getTokenURI(uint256 tokenId) public view returns (string memory) {
    return _tokenURIs[tokenId];
  }

  /**
   * @dev Gets the total number of domains minted.
   * @return The total number of domains minted.
  */
  function totalSupply() public view returns (uint256) {
    return _domainIds.current();
  }

  /**
   * @dev Burns a domain.
   * @param tokenId The ID of the domain to burn.
  */
  function burn(uint256 tokenId, address owner) public {
    require(_isApprovedOrOwner(owner, tokenId), "ZNSDomain: caller is not owner nor approved");
    _burn(tokenId);
  }

  /**
    @dev Internal function to burn a domain.
    @param tokenId uint256 ID of the token to be burned.
    Requirements:
    The caller must be approved or owner of the token.
    The token must exist.
  */
  function _burn(uint256 tokenId) internal override(ERC721Upgradeable) {
    super._burn(tokenId);
    delete _tokenURIs[tokenId];
    _domainIds.decrement();
  }

  uint256[49] private __gap;
}