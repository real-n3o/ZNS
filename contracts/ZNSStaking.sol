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
    // why is this value needed? it doesn't seem to be used anywhere in code
    uint256 startTime;
    // we can just get owner from the token contract
    // the existence of this might create discrepancy in the system
    // unless there's a specific purpose for having this different from the token owner
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
    // no addresses are checked here, which can create all sorts of errors in prod
    znsDomain = _znsDomain;
    stakingToken = _stakingToken;
  }

  /**
    @dev Adds a stake to the contract for the given domain tokenId.
    Only the owner of the domain can add a stake.
    The amount of stake to be added must be greater than 0.
    The unallocated stake in the contract must be greater than or equal to the amount of stake to be added.
  */
  // function is not protected
  function addStake(uint256 tokenId, uint256 amount, address recipient) public {
    // this is an interesting case. I wonder if this can fail at any point with
    // some changes to contracts since owner is being assigned to the token in the same transaction.
    // In any way, it's better to take the stake first, then assign the owner to reduce reentrancy risk,
    // which would make this check fail every time.
    require(znsDomain.ownerOf(tokenId) == recipient, "ZNSStaking: Only the domain owner can add stake");
    // since this comes from Registrar, the value corresponding to it is `domainCost`,
    // which should be checked at the Registrar level upon setting it to storage
    // making this check redundant. we would prefer that over this check,
    // since this imposes an unnecessary gas cost on the user.
    // we do not want to check this every time a stake is added.
    require(amount > 0, "ZNSStaking: Amount must be greater than 0");

    // this is not a good flow, in my opinion, and can create problems down the line.
    // this contract should withdraw the stake by itself, not rely on another module to do it.
    // when we do it this way, this check is not needed, since it is already
    // not giving us clear picture. these unallocated funds can be anything in theory,
    // so relying on this is not safe.
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
  // this function makes it possible to withdraw your stake without burning the token
  // so a user can register a domain, pay for it, then take his money back and still keep the domain.
  // another thing here is that it is enough to know who owns the domain to withdraw the stake for someone else,
  // creating discrepancy in the system. anybody can call this
  // as long as they know the owner of the stake which they can pull from this same contract.
  function withdrawStake(uint256 tokenId, address recipient) public {
    require(znsDomain.ownerOf(tokenId) == recipient, "ZNSStaking: Only the domain owner can withdraw stake");
    require(recipient != address(0), "ZNSStaking: Recipient address cannot be zero");

    // Check that the stake exists for tokenID + recipient
    Stake memory stake = stakes[tokenId];
    // if there's a reason to have this check in place - there's something fishy with the system code
    // this should technically not be possible that a stake for an existing domain is not present
    require(stake.amount > 0, "ZNSStaking: No stake found for the given tokenId");
    // why do we need to check both owner here (token + stake)?
    // is there a reason they are different? and in what case they can be different?
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