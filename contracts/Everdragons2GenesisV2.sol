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
import "@ndujalabs/wormhole721/contracts/Wormhole721Upgradeable.sol";

import "./interfaces/IStakingPool.sol";
import "./interfaces/IEverdragons2Bridge.sol";

//import "hardhat/console.sol";

contract Everdragons2GenesisV2 is
  Initializable,
  ERC721Upgradeable,
  ERC721PlayableUpgradeable,
  ERC721EnumerableUpgradeable,
  Wormhole721Upgradeable
{
  bool private _mintEnded;
  bool private _baseTokenURIFrozen;
  string private _baseTokenURI;

  address public manager;

  mapping(address => bool) public pools;
  mapping(uint256 => address) public staked;
  IEverdragons2Bridge public bridge;

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

  function airdrop(address[] memory recipients, uint256[] memory tokenIds) external onlyOwner {
    require(totalSupply() < 600, "Airdrop completed");
    require(recipients.length == tokenIds.length, "Inconsistent lengths");
    for (uint256 i = 0; i < recipients.length; i++) {
      require(tokenIds[i] < 601, "ID out of range");
      if (totalSupply() < 601) {
        _safeMint(recipients[i], tokenIds[i]);
      } else {
        _mintEnded = true;
        return;
      }
    }
    if (totalSupply() == 600) {
      _mintEnded = true;
    }
  }

  function mintEnded() public view virtual returns (bool) {
    return _mintEnded;
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
    return string(abi.encodePacked(_baseTokenURI, "0"));
  }

  // stakes

  function isStaked(uint256 tokenId) public view returns (bool) {
    return staked[tokenId] != address(0);
  }

  function getStaker(uint256 tokenId) external view returns (address) {
    return staked[tokenId];
  }

  function setPool(address pool) external onlyOwner {
    require(IStakingPool(pool).id() == keccak256("Everdragons2Pool"), "Not a pool");
    pools[pool] = true;
  }

  function removePool(address pool) external onlyOwner {
    require(pools[pool], "Not an active pool");
    delete pools[pool];
  }

  function hasStakes(address owner) public view returns (bool) {
    uint256 balance = balanceOf(owner);
    for (uint256 i = 0; i < balance; i++) {
      uint256 id = tokenOfOwnerByIndex(owner, i);
      if (isStaked(id)) {
        return true;
      }
    }
    return false;
  }

  function stake(uint256 tokenId) external onlyPool {
    // will revert if token does not exist
    ownerOf(tokenId);
    staked[tokenId] = _msgSender();
  }

  function unstake(uint256 tokenId) external onlyPool {
    // will revert if token does not exist
    require(staked[tokenId] == _msgSender(), "Wrong pool");
    delete staked[tokenId];
  }

  // emergency function in case a compromised pool is removed
  function unstakeIfRemovedPool(uint256 tokenId) external onlyOwner {
    require(isStaked(tokenId), "Not a staked tokenId");
    require(!pools[staked[tokenId]], "Pool is active");
    delete staked[tokenId];
  }

  // manage approval

  function approve(address to, uint256 tokenId) public override  {
    require(!isStaked(tokenId), "Dragon is staked");
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view override returns (address) {
    if (isStaked(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address operator, bool approved) override public {
    require(!approved || !hasStakes(_msgSender()), "At least one dragon is staked");
    super.setApprovalForAll(operator, approved);
  }

  function isApprovedForAll(address owner, address operator) public override view returns (bool) {
    if (hasStakes(owner)) {
      return false;
    }
    return super.isApprovedForAll(owner, operator);
  }

  // bridge

  function setBridge(IEverdragons2Bridge bridge_) external onlyOwner {
    require(bridge_.id() == keccak256("Everdragons2Bridge"), "Not a bridge");
    bridge = bridge_;
  }

  function crossChainTransfer(
    uint256 tokenId,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) external {
    require(!isStaked(tokenId), "Token is staked");
    require(_isApprovedOrOwner(_msgSender(), tokenId), "Transfer caller is not owner nor approved");
    bridge.wormholeTransfer(tokenId, recipientChain, recipient, nonce);
  }

  function completeCrossChainTransfer(bytes memory encodedVm) external {
    bridge.wormholeCompleteTransfer(encodedVm);
  }

  // deprecated

  function wormholeTransfer(
    uint256 tokenId,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable virtual override returns (uint64 sequence) {
    revert("Deprecated");
  }


  function wormholeCompleteTransfer(bytes memory encodedVm) public virtual override {
    revert("Deprecated");
  }

}
