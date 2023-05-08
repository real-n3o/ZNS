/**
  @title ZNSStaking
  @dev Contract for managing staking related to ZNS domains
  SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ZNSStaking
 * @dev Staking contract for Zero Name Service (ZNS) domains.
*/
contract ZNSStaking is Initializable {
  using SafeMathUpgradeable for uint256;
  bool private _initialized;

  struct Stake {
    uint256 amount;
    uint256 startTime;
    address ownerOf;
  }

  mapping(uint256 => Stake) public stakes;

  IERC721Upgradeable public znsDomain;
  IERC20Upgradeable public stakingToken;

  /**
    * @dev Emitted when stake is added to a domain.
    * @param tokenId The ID of the domain that had stake added to it.
    * @param amount The amount of stake added to the domain.
    * @param startTime The time when the stake was added.
    * @param ownerOf The address of the owner of the domain.
  */
  event StakeAdded(uint256 indexed tokenId, uint256 amount, uint256 startTime, address ownerOf);

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
  function initialize(IERC721Upgradeable _znsDomain, IERC20Upgradeable _stakingToken) public initializer {
    require(!_initialized, "ZNSStaking: Contract is already initialized");
    __ZNSStaking_init(_znsDomain, _stakingToken);
    _initialized = true;
  }

  function __ZNSStaking_init(IERC721Upgradeable _znsDomain, IERC20Upgradeable _stakingToken) internal {
    znsDomain = _znsDomain;
    stakingToken = _stakingToken;
  }

  /**
    @dev Adds a stake to the contract for the given domain tokenId.
    Only the owner of the domain can add a stake.
    The amount of stake to be added must be greater than 0.
    The unallocated stake in the contract must be greater than or equal to the amount of stake to be added.
  */
  function addStake(uint256 tokenId, uint256 amount, address recipient) public {
    require(znsDomain.ownerOf(tokenId) == recipient, "ZNSStaking: Only the domain owner can add stake");
    require(amount > 0, "ZNSStaking: Amount must be greater than 0");

    // Check that the unallocated stake is enough for the stake being added
    uint256 unallocatedStake = stakingToken.balanceOf(address(this));
    require(unallocatedStake >= amount, "ZNSStaking: Insufficient unallocated stake");

    // Add stake to the mapping with msg.sender as the owner
    stakes[tokenId] = Stake(amount, block.timestamp, recipient);

    // Emit event
    emit StakeAdded(tokenId, amount, block.timestamp, recipient);
  }
  
  /**
    @dev Withdraws the stake from the contract for the given domain tokenId.
    Only the owner of the domain can withdraw the stake.
    The recipient address must not be 0.
  */
  function withdrawStake(uint256 tokenId, address recipient) public {
    require(znsDomain.ownerOf(tokenId) == recipient, "ZNSStaking: Only the domain owner can withdraw stake");
    require(recipient != address(0), "ZNSStaking: Recipient address cannot be zero");

    // Check that the stake exists for tokenID + recipient
    Stake memory stake = stakes[tokenId];
    require(stake.amount > 0, "ZNSStaking: No stake found for the given tokenId");
    require(stake.ownerOf == recipient, "ZNSStaking: Only the owner of the stake can withdraw it");

    // Remove stake from mapping
    delete stakes[tokenId];

    // Transfer tokens back to domain owner
    SafeERC20Upgradeable.safeTransfer(stakingToken, recipient, stake.amount);

    // Emit event
    emit StakeWithdrawn(tokenId, stake.amount, recipient);
  }

  // For storage layout future-proofing
  uint256[49] private __gap;
}