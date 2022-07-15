// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// Everdragons2, https://everdragons2.com

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@ndujalabs/wormhole721/contracts/Wormhole721Upgradeable.sol";

import "./interfaces/IStakingPool.sol";

import "hardhat/console.sol";

contract Everdragons2PfP is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, Wormhole721Upgradeable {
  using AddressUpgradeable for address;

  bool private _mintEnded;
  bool private _baseTokenURIFrozen;
  string private _baseTokenURI;

  ERC721EnumerableUpgradeable public genesisToken;

  mapping(address => bool) public pools;
  mapping(uint256 => address) public staked;

  modifier onlyPool() {
    require(pools[_msgSender()], "Forbidden");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize() public initializer {
    __Wormhole721_init("Everdragons2 PfP", "E2PfP");
    __ERC721Enumerable_init();
    // tokenURI pre-reveal
    _baseTokenURI = "https://img.everdragons2.com/e2gt/";
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function setGenesisToken(address token) external onlyOwner {
    require(token.isContract(), "Not a contract");
    genesisToken = ERC721EnumerableUpgradeable(token);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
    require(!isStaked(tokenId), "Dragon is staked");
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(Wormhole721Upgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function claim() external {
    require(address(genesisToken) != address(0), "Genesis token not set");
    uint256 balance = genesisToken.balanceOf(_msgSender());
    uint256 k = 0;
    for (uint256 i = 0; i < balance; i++) {
      uint256 tokenId = genesisToken.tokenOfOwnerByIndex(_msgSender(), i);
      if (!_exists(tokenId)) {
        _safeMint(_msgSender(), tokenId);
        k++;
        if (k == 10) {
          break;
        }
      }
    }
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

  function isStaked(uint256 tokenID) public view returns (bool) {
    return staked[tokenID] != address(0);
  }

  function getStaker(uint256 tokenID) external view returns (address) {
    return staked[tokenID];
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

  function stake(uint256 tokenID) external onlyPool {
    // pool must be approved to mark the token as staked
    require(getApproved(tokenID) == _msgSender() || isApprovedForAll(ownerOf(tokenID), _msgSender()), "Pool not approved");
    staked[tokenID] = _msgSender();
  }

  function unstake(uint256 tokenID) external onlyPool {
    // will revert if token does not exist
    require(staked[tokenID] == _msgSender(), "Wrong pool");
    delete staked[tokenID];
  }

  // emergency function in case a compromised pool is removed
  function unstakeIfRemovedPool(uint256 tokenID) external onlyOwner {
    require(isStaked(tokenID), "Not a staked tokenID");
    require(!pools[staked[tokenID]], "Pool is active");
    delete staked[tokenID];
  }

  // manage approval

  function approve(address to, uint256 tokenId) public override {
    console.log(tokenId);
    require(!isStaked(tokenId), "Dragon is staked");
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view override returns (address) {
    if (isStaked(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address operator, bool approved) public override {
    require(!approved || !hasStakes(_msgSender()), "At least one dragon is staked");
    super.setApprovalForAll(operator, approved);
  }

  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
    if (hasStakes(owner)) {
      return false;
    }
    return super.isApprovedForAll(owner, operator);
  }
}
