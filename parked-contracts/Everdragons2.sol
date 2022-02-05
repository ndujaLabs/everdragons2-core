// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// Everdragons2, https://everdragons2.com

import "@ndujalabs/erc721playable/contracts/ERC721PlayableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@ndujalabs/wormhole721/contracts/Wormhole721Upgradeable.sol";

import "./IEverdragons2.sol";

import "hardhat/console.sol";

contract Everdragons2 is
  IEverdragons2,
  Initializable,
  ERC721Upgradeable,
  ERC721PlayableUpgradeable,
  ERC721EnumerableUpgradeable,
  Wormhole721Upgradeable
{
  //using Address for address;
  address public manager;
  bool private _mintEnded;
  bool private _baseTokenURIFrozen;

  string private _baseTokenURI;
  uint256 private _lastTokenId;

  mapping(uint256 => bool) private _isMinted;

  modifier onlyManager() {
    require(manager != address(0) && _msgSender() == manager, "Forbidden");
    _;
  }

  modifier canMint() {
    require(!_mintEnded, "Minting ended or not allowed");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(uint256 lastTokenId_, bool secondaryChain) public initializer {
    __Wormhole721_init("Everdragons2 Genesis", "E2G");
    __ERC721Enumerable_init();
    _lastTokenId = lastTokenId_;
    if (secondaryChain) {
      // if so, it is a bridged version of the token and cannot be minted by a manager
      _mintEnded = true;
    } else {
      // Agdaroth
      _mint(msg.sender, lastTokenId_);
    }
    // temporary tokenURI:
    _baseTokenURI = "https://img.everdragons2.com/e2g/";
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  // The following functions are overrides required by Solidity.

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

  function isMinted(uint256 tokenId) external view override returns (bool) {
    return _isMinted[tokenId];
  }

  function lastTokenId() external view override returns (uint256) {
    return _lastTokenId;
  }

  function setManager(address manager_) external override onlyOwner canMint {
    require(manager_ != address(0), "Manager cannot be 0x0");
    manager = manager_;
  }

  function mint(address recipient, uint256[] memory tokenIds) external override onlyManager canMint {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      mint(recipient, tokenIds[i]);
    }
  }

  function mint(address[] memory recipients, uint256[] memory tokenIds) external override onlyManager canMint {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      mint(recipients[i], tokenIds[i]);
    }
  }

  function mint(address recipient, uint256 tokenId) public override onlyManager canMint {
    _isMinted[tokenId] = true;
    _safeMint(recipient, tokenId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateBaseTokenURI(string memory uri) external override onlyOwner {
    require(!_baseTokenURIFrozen, "baseTokenUri has been frozen");
    // after revealing, this allows to set up a final uri
    _baseTokenURI = uri;
  }

  function freezeBaseTokenURI() external override onlyOwner {
    _baseTokenURIFrozen = true;
  }

  function endMinting() external override onlyOwner {
    _mintEnded = true;
  }

  function mintEnded() external view override returns (bool) {
    return _mintEnded;
  }

  function contractURI() public view returns (string memory) {
    return _baseURI();
  }
}
