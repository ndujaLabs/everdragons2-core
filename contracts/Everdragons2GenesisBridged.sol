// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>
// Everdragons2, https://everdragons2.com

import "@ndujalabs/erc721playable/contracts/ERC721PlayableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./interfaces/IEverdragons2Genesis.sol";
import "./interfaces/IEverdragons2Bridge.sol";
import "./interfaces/IStakingPool.sol";

import "hardhat/console.sol";

contract Everdragons2GenesisBridged is
  IEverdragons2Genesis,
  Initializable,
  ERC721Upgradeable,
  ERC721PlayableUpgradeable,
  ERC721EnumerableUpgradeable,
  OwnableUpgradeable,
  UUPSUpgradeable
{
  using AddressUpgradeable for address;

  bool private _airdropCompleted;
  bool private _baseTokenURIFrozen;
  string private _baseTokenURI;
  uint256 private _maxSupply;

  IEverdragons2Bridge public bridge;
  mapping(address => bool) public pools;
  mapping(uint256 => address) public staked;
  mapping(bytes4 => bool) private _usedEVMs;

  modifier onlyBridge() {
    require(address(bridge) != address(0) && _msgSender() == address(bridge), "Forbidden");
    _;
  }

  modifier onlyPool() {
    require(pools[_msgSender()], "Forbidden");
    _;
  }

  modifier whenNotStaked(uint256 tokenID) {
    require(!isStaked(tokenID), "Token is staked");
    _;
  }

  modifier whenAirdropCompleted() {
    require(_airdropCompleted == false, "Airdrop not completed");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(string memory baseTokenURI) public initializer {
    __Ownable_init();
    __ERC721_init("Everdragons2 Genesis Token", "EVD2");
    __ERC721Enumerable_init();
    _baseTokenURI = baseTokenURI;
    _maxSupply = 600;
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function id() external view override returns (bytes32) {
    return keccak256("Everdragons2Genesis");
  }

  // tokenURI

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external override onlyOwner {
    require(!_baseTokenURIFrozen, "baseTokenUri has been frozen");
    // after revealing, this allows to set up a final uri
    _baseTokenURI = uri;
  }

  function freezeTokenURI() external override onlyOwner {
    _baseTokenURIFrozen = true;
  }

  // bridge

  function setBridge(IEverdragons2Bridge bridge_) external override onlyOwner {
    require(bridge_.id() == keccak256("Everdragons2Bridge"), "Not a bridge");
    bridge = bridge_;
  }

  function crossChainTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) external override whenNotStaked(tokenID) whenAirdropCompleted {
    require(_isApprovedOrOwner(_msgSender(), tokenID), "Transfer caller is not owner nor approved");
    bridge.wormholeTransfer(tokenID, recipientChain, recipient, nonce);
  }

  function completeCrossChainTransfer(bytes memory encodedVm) external override {
    bridge.wormholeCompleteTransfer(encodedVm);
  }

  function mint(
    address to,
    uint256 tokenID,
    bytes4 evm
  ) external override onlyBridge whenAirdropCompleted {
    require(tokenID <= _maxSupply, "tokenID out of range");
    require(!_usedEVMs[evm], "tokenID already minted for this evm");
    _usedEVMs[evm] = true;
    _safeMint(to, tokenID);
  }

  function burn(uint256 tokenID) external override onlyBridge whenAirdropCompleted whenNotStaked(tokenID) {
    _burn(tokenID);
  }

  // stakes

  function isStaked(uint256 tokenID) public view override returns (bool) {
    return staked[tokenID] != address(0);
  }

  function setPool(address pool) external override onlyOwner {
    require(IStakingPool(pool).id() == keccak256("Everdragons2Pool"), "Not a pool");
    pools[pool] = true;
  }

  function removePool(address pool) external override onlyOwner {
    require(pools[pool], "Not an active pool");
    delete pools[pool];
  }

  function approve(address to, uint256 tokenId) public override {
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view override returns (address) {
    if (isStaked(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function hasStakes(address owner) public view override returns (bool) {
    uint256 balance = balanceOf(owner);
    for (uint256 i = 0; i < balance; i++) {
      uint256 id = tokenOfOwnerByIndex(owner, i);
      if (isStaked(id)) {
        return true;
      }
    }
    return false;
  }

  function setApprovalForAll(address operator, bool approved) public override {
    if (!hasStakes(_msgSender())) {
      super.setApprovalForAll(operator, approved);
    }
  }

  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
    if (hasStakes(owner)) {
      return false;
    }
    return super.isApprovedForAll(owner, operator);
  }

  function stake(uint256 tokenID) external override onlyPool whenAirdropCompleted {
    // will revert if token does not exist
    ownerOf(tokenID);
    staked[tokenID] = _msgSender();
  }

  function unstake(uint256 tokenID) external override onlyPool {
    // will revert if token does not exist
    require(staked[tokenID] == _msgSender(), "Wrong pool");
    delete staked[tokenID];
  }

  // emergency function in case a compromised pool is removed
  function unstakeIfRemovedPool(uint256 tokenID) external override onlyOwner {
    require(isStaked(tokenID), "Not a staked tokenID");
    require(!pools[staked[tokenID]], "Pool is active");
    delete staked[tokenID];
  }

  uint256[50] private __gap;
}
