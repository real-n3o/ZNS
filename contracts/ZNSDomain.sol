/**
  @title ZNSDomain
  @dev Contract for issuing ZNS domains
  SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.0;

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

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

  /**
   * @dev Initializes the contract.
  */
  function initialize() public initializer {
    __ERC721_init("Zero Name Service (ZNS)", "ZNS");
  }

  /**
   * @dev Mint a new domain.
   * @param to The address to mint the domain to.
   * @return The ID of the newly minted domain.
  */
  // this functions is not protected, meaning anyone can come and mint a domain,
  // circumventing the Registrar contract and it's required flows (payments, Registrar state update, etc.)
  function mintDomain(address to) external returns (uint256) {
    // Validate inputs
    require(to != address(0), "ZNSDomain: Invalid address");

    // Increment domain ID
    _domainIds.increment();

    // Mint new domain 
    uint256 newDomainId = _domainIds.current();
    _safeMint(to, newDomainId);

    return newDomainId;
  }

  /**
   * @dev Gets the URI of the domain metadata.
   * @param tokenId The ID of the domain to get the URI for.
   * @return The URI of the domain metadata.
  */
  function getTokenURI(uint256 tokenId) public view returns (string memory) {
    return super.tokenURI(tokenId);
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
    _domainIds.decrement();
  }

  uint256[49] private __gap;
}