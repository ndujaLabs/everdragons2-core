// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// Everdragons2, https://everdragons2.com

import "@ndujalabs/erc721playable/contracts/IERC721Playable.sol";
import "@ndujalabs/erc721playable/contracts/ERC721PlayableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../wormhole721/Wormhole721Upgradeable.sol";
import "@ndujalabs/erc721attributable/contracts/IERC721Attributable.sol";
import "@ndujalabs/erc721lockable/contracts/IERC721Lockable.sol";

import "./interfaces/IStakingPool.sol";

//import "hardhat/console.sol";

contract Everdragons2GenesisBridgedV3 is
  IERC721Lockable,
  IERC721Attributable,
  ERC721Upgradeable,
  ERC721PlayableUpgradeable,
  ERC721EnumerableUpgradeable,
  Wormhole721Upgradeable
{
  using AddressUpgradeable for address;

  error NotALocker();
  error NotTheAssetOwner();
  error PlayerAlreadyAuthorized();
  error PlayerNotAuthorized();
  error NotAContract();
  error NotADeactivatedLocker();
  error WrongLocker();
  error NotLockedAsset();
  error LockedAsset();
  error AtLeastOneLockedAsset();
  error LockerNotApproved();
  error BaseTokenUriHasBeenFrozen();

  bool private _baseTokenURIFrozen;
  string private _baseTokenURI;

  mapping(address => bool) public pools;
  mapping(uint256 => address) public staked;

  // added in V3
  mapping(address => bool) private _lockers;
  mapping(uint256 => mapping(address => mapping(uint256 => uint256))) internal _tokenAttributes;

  modifier onlyLocker() {
    if (!_lockers[_msgSender()]) {
      revert NotALocker();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize() public initializer {
    __Wormhole721_init("Everdragons2 Genesis Token", "E2GT");
    __ERC721Enumerable_init();
    // tokenURI pre-reveal
    _baseTokenURI = "https://img.everdragons2.com/e2gt/";
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable) {
    if (isLocked(tokenId)) {
      revert LockedAsset();
    }
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(Wormhole721Upgradeable, ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
  {
    if (type(IERC721Playable).interfaceId == interfaceId) return false;
    return
      interfaceId == type(IERC721Attributable).interfaceId ||
      interfaceId == type(IERC721Lockable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external onlyOwner {
    if (_baseTokenURIFrozen) revert BaseTokenUriHasBeenFrozen();
    // after revealing, this allows to set up a final uri
    _baseTokenURI = uri;
  }

  function freezeTokenURI() external onlyOwner {
    _baseTokenURIFrozen = true;
  }

  function contractURI() public view returns (string memory) {
    return _baseURI();
  }

  // Attributable implementation

  function attributesOf(
    uint256 _id,
    address _player,
    uint256 _index
  ) external view override returns (uint256) {
    return _tokenAttributes[_id][_player][_index];
  }

  function initializeAttributesFor(uint256 _id, address _player) external override {
    if (ownerOf(_id) != _msgSender()) {
      revert NotTheAssetOwner();
    }
    if (_tokenAttributes[_id][_player][0] > 0) {
      revert PlayerAlreadyAuthorized();
    }
    _tokenAttributes[_id][_player][0] = 1;
    emit AttributesInitializedFor(_id, _player);
  }

  function updateAttributes(
    uint256 _id,
    uint256 _index,
    uint256 _attributes
  ) external override {
    if (_tokenAttributes[_id][_msgSender()][0] == 0) {
      revert PlayerNotAuthorized();
    }
    // notice that if the playes set the attributes to zero, it de-authorize itself
    // and not more changes will be allowed until the NFT owner authorize it again
    _tokenAttributes[_id][_msgSender()][_index] = _attributes;
  }

  // IERC721Lockable
  //
  // When a contract is locked, only the locker is approved
  // The advantage of locking an NFT instead of staking is that
  // The owner keeps the ownership of it and can use that, for example,
  // to access services on Discord via Collab.land verification.

  function isLocked(uint256 tokenId) public view override returns (bool) {
    return staked[tokenId] != address(0);
  }

  function lockerOf(uint256 tokenId) external view override returns (address) {
    return staked[tokenId];
  }

  function isLocker(address locker) public view override returns (bool) {
    return _lockers[locker];
  }

  function setLocker(address locker) external override onlyOwner {
    if (!locker.isContract()) {
      revert NotAContract();
    }
    _lockers[locker] = true;
    emit LockerSet(locker);
  }

  function removeLocker(address locker) external override onlyOwner {
    if (!_lockers[locker]) {
      revert NotALocker();
    }
    delete _lockers[locker];
    emit LockerRemoved(locker);
  }

  function hasLocks(address owner) public view override returns (bool) {
    uint256 balance = balanceOf(owner);
    for (uint256 i = 0; i < balance; i++) {
      uint256 id = tokenOfOwnerByIndex(owner, i);
      if (isLocked(id)) {
        return true;
      }
    }
    return false;
  }

  function lock(uint256 tokenId) external override onlyLocker {
    if (getApproved(tokenId) != _msgSender() && !isApprovedForAll(ownerOf(tokenId), _msgSender())) {
      revert LockerNotApproved();
    }
    staked[tokenId] = _msgSender();
    emit Locked(tokenId);
  }

  function unlock(uint256 tokenId) external override onlyLocker {
    // will revert if token does not exist
    if (staked[tokenId] != _msgSender()) {
      revert WrongLocker();
    }
    delete staked[tokenId];
    emit Unlocked(tokenId);
  }

  // emergency function in case a compromised locker is removed
  function unlockIfRemovedLocker(uint256 tokenId) external override onlyOwner {
    if (!isLocked(tokenId)) {
      revert NotLockedAsset();
    }
    if (_lockers[staked[tokenId]]) {
      revert NotADeactivatedLocker();
    }
    delete staked[tokenId];
    emit ForcefullyUnlocked(tokenId);
  }

  // To obtain the lockability, the standard approval and transfer
  // functions of an ERC721 must be overridden, taking in consideration
  // the locking status of the NFT.

  // The _beforeTokenTransfer hook is enough to guarantee that a locked
  // NFT cannot be transferred. Overriding the approval functions, following
  // OpenZeppelin best practices, avoid the user to spend useless gas.

  function approve(address to, uint256 tokenId) public override(ERC721Upgradeable) {
    if (isLocked(tokenId)) {
      revert LockedAsset();
    }
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view override(ERC721Upgradeable) returns (address) {
    if (isLocked(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address operator, bool approved) public override(ERC721Upgradeable) {
    if (approved && hasLocks(_msgSender())) {
      revert AtLeastOneLockedAsset();
    }
    super.setApprovalForAll(operator, approved);
  }

  function isApprovedForAll(address owner, address operator) public view override(ERC721Upgradeable) returns (bool) {
    if (hasLocks(owner)) {
      return false;
    }
    return super.isApprovedForAll(owner, operator);
  }

  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable override returns (uint64 sequence) {
    if (isLocked(tokenID)) revert LockedAsset();
    return super.wormholeTransfer(tokenID, recipientChain, recipient, nonce);
  }
}
