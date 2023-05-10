/**
  @title ZNSStaking
  @dev Contract for managing staking related to ZNS domains
  SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.0;

import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { ZNSDomain } from "./ZNSDomain.sol";

/**
 * @title ZNSStaking
 * @dev Staking contract for Zero Name Service (ZNS) domains.
*/
contract ZNSStaking is Initializable {
  using SafeMathUpgradeable for uint256;

  mapping(uint256 => uint256) public stakes;

  ZNSDomain public znsDomain;
  IERC20Upgradeable public stakingToken;

  /**
    * @dev Emitted when stake is added to a domain.
    * @param tokenId The ID of the domain that had stake added to it.
    * @param amount The amount of stake added to the domain.
    * @param ownerOf The address of the owner of the domain.
  */
  event StakeAdded(uint256 indexed tokenId, uint256 amount, address ownerOf);

  /**
    * @dev Emitted when stake is withdrawn from a domain.
    * @param tokenId The ID of the domain that had stake withdrawn from it.
    * @param amount The amount of stake withdrawn from the domain.
    * @param recipient The address of the recipient of the withdrawn stake.
  */
  event StakeWithdrawn(uint256 indexed tokenId, uint256 amount, address indexed recipient);

  /**
    @dev Initializes the contract with the addresses of ZNS domains and staking tokens.
  */
  function initialize(ZNSDomain _znsDomain, IERC20Upgradeable _stakingToken) public initializer {
    __ZNSStaking_init(_znsDomain, _stakingToken);
  }

  function __ZNSStaking_init(ZNSDomain _znsDomain, IERC20Upgradeable _stakingToken) internal {
    require(_znsDomain != ZNSDomain(address(0)), "Invalid ZNSDomain address");
    require(_stakingToken != IERC20Upgradeable(address(0)), "Invalid ZNSDomain address");

    znsDomain = _znsDomain;
    stakingToken = _stakingToken;
  }

  /**
    @dev Adds a stake to the contract for the given domain tokenId.
    Only the owner of the domain can add a stake.
  */
  // function is not protected
  function addStake(uint256 tokenId, uint256 domainCost) public {
    // Transfer funds to the recipient to the staking contract
    SafeERC20Upgradeable.safeTransferFrom(stakingToken, tx.origin, address(this), domainCost);

    // Add stake to the mapping with msg.sender as the owner
    stakes[tokenId] = domainCost;

    // Emit event
    emit StakeAdded(tokenId, domainCost, znsDomain.ownerOf(tokenId));
  }

  /**
    @dev Withdraws the stake from the contract for the given domain tokenId.
    Only the owner of the domain can withdraw the stake.
    The recipient address must not be 0.
  */
  function withdrawStake(uint256 tokenId) public {
    require(znsDomain.ownerOf(tokenId) == tx.origin, "ZNSStaking: Only the domain owner can withdraw stake");
    require(tx.origin != address(0), "ZNSStaking: Recipient address cannot be zero");

    // Check that the stake exists for tokenID + recipient
    uint256 stakedAmount = stakes[tokenId];

    // Remove stake from mapping
    delete stakes[tokenId];

    // Burn the domain
    znsDomain.burn(tokenId, tx.origin);

    // Transfer tokens back to domain owner
    SafeERC20Upgradeable.safeTransfer(stakingToken, tx.origin, stakedAmount);

    // Emit event
    emit StakeWithdrawn(tokenId, stakedAmount, tx.origin);
  }

  // For storage layout future-proofing
  uint256[49] private __gap;
}