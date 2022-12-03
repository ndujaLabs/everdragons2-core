// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// Everdragons2, https://everdragons2.com

import "@ndujalabs/erc721playable/contracts/ERC721PlayableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@ndujalabs/wormhole721-0-3-0/contracts/Wormhole721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@ndujalabs/attributable/contracts/IAttributable.sol";

import "./interfaces/IStakingPool.sol";

import "./interfaces/ILockable.sol";

//import "hardhat/console.sol";

contract Everdragons2GenesisBridgedV3 is
  ILockable,
  IAttributable,
  Initializable,
  ERC721Upgradeable,
  ERC721PlayableUpgradeable,
  ERC721EnumerableUpgradeable,
  Wormhole721Upgradeable
{
  using AddressUpgradeable for address;

  bool private _baseTokenURIFrozen;
  string private _baseTokenURI;

  mapping(address => bool) public pools;
  mapping(uint256 => address) public staked;

  mapping(uint256 => mapping(address => mapping(uint8 => uint256))) internal _tokenAttributes;

  modifier onlyPool() {
    require(pools[_msgSender()], "Forbidden");
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
    require(!isLocked(tokenId), "Dragon is staked");
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(Wormhole721Upgradeable, ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external onlyOwner {
    require(!_baseTokenURIFrozen, "baseTokenUri has been frozen");
    // after revealing, this allows to set up a final uri
    _baseTokenURI = uri;
  }

  function freezeTokenURI() external onlyOwner {
    _baseTokenURIFrozen = true;
  }

  function contractURI() public view returns (string memory) {
    return _baseURI();
  }

  // locks

  function isLocked(uint256 tokenId) public view override returns (bool) {
    return staked[tokenId] != address(0);
  }

  function lockerOf(uint256 tokenId) external view override returns (address) {
    return staked[tokenId];
  }

  function isLocker(address locker) public view override returns (bool) {
    return pools[locker];
  }

  function setLocker(address locker) external override onlyOwner {
    require(locker.isContract(), "locker not a contract");
    pools[locker] = true;
    emit LockerSet(locker);
  }

  function removeLocker(address locker) external override onlyOwner {
    require(pools[locker], "not an active locker");
    delete pools[locker];
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

  function lock(uint256 tokenId) external override onlyPool {
    // locker must be approved to mark the token as locked
    require(isLocker(_msgSender()), "Not an authorized locker");
    require(getApproved(tokenId) == _msgSender() || isApprovedForAll(ownerOf(tokenId), _msgSender()), "Locker not approved");
    staked[tokenId] = _msgSender();
    emit Locked(tokenId);
  }

  function unlock(uint256 tokenId) external override onlyPool {
    // will revert if token does not exist
    require(staked[tokenId] == _msgSender(), "wrong locker");
    delete staked[tokenId];
    emit Unlocked(tokenId);
  }

  // emergency function in case a compromised locker is removed
  function unlockIfRemovedLocker(uint256 tokenId) external override onlyOwner {
    require(isLocked(tokenId), "not a locked tokenId");
    require(!pools[staked[tokenId]], "locker is still active");
    delete staked[tokenId];
    emit ForcefullyUnlocked(tokenId);
  }

  // manage approval

  function approve(address to, uint256 tokenId) public override {
    require(!isLocked(tokenId), "locked asset");
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view override returns (address) {
    if (isLocked(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address operator, bool approved) public override {
    require(!approved || !hasLocks(_msgSender()), "at least one asset is locked");
    super.setApprovalForAll(operator, approved);
  }

  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
    if (hasLocks(owner)) {
      return false;
    }
    return super.isApprovedForAll(owner, operator);
  }

  // attributable

  function attributesOf(
    uint256 _id,
    address _player,
    uint8 _index
  ) external view override returns (uint256) {
    return _tokenAttributes[_id][_player][_index];
  }

  function authorizePlayer(uint256 _id, address _player) external override {
    require(ownerOf(_id) == _msgSender(), "Not the owner");
    require(_tokenAttributes[_id][_player][0] == 0, "Player already authorized");
    _tokenAttributes[_id][_player][0] = 1;
  }

  function updateAttributes(
    uint256 _id,
    uint8 _index,
    uint256 _attributes
  ) external override {
    require(_tokenAttributes[_id][_msgSender()][0] != 0, "Player not authorized");
    // notice that if the playes set the attributes to zero, it de-authorize itself
    // and not more changes will be allowed until the NFT owner authorize it again
    _tokenAttributes[_id][_msgSender()][_index] = _attributes;
  }
}
