// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// EverDragons2, https://everdragons2.com

import "@ndujalabs/erc721playable/contracts/ERC721PlayableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./IEverDragons2.sol";
import "./Wormhole/WormholeERC721.sol";

import "hardhat/console.sol";

contract EverDragons2 is IEverDragons2, Initializable, ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, WormholeERC721, UUPSUpgradeable {
  //using Address for address;
  address public manager;
  bool private _mintEnded;
  bool private _baseTokenURIFrozen;

  string private _baseTokenURI;
  uint256 private _lastTokenId;

  address[] private _teamWallets;

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

  function initialize(uint256 lastTokenId_, bool secondaryChain) initializer public {
    __ERC721_init("Everdragons2 Genesis Token", "E2GT");
    __ERC721Enumerable_init();
    __ERC721Burnable_init();
    __Ownable_init();

    _teamWallets = [
      0x70f41fE744657DF9cC5BD317C58D3e7928e22E1B,
      0x0ECE90EF4a12273E9c2C06E7C86075d021DB5A6A,
      //
      0x70f41fE744657DF9cC5BD317C58D3e7928e22E1B,
      0x16244cdFb0D364ac5c4B42Aa530497AA762E7bb3,
      0xe360cDb9B5348DB79CD630d0D1DE854b44638C64,
      0xE14615C5B0d4f262153343e1590f196DCd52164e,
      0x777eFBFd78D38Acd0753ef2eBe7cdA620C0f409a,
      0xca17b266C872aAa553d2fC2e13187EcE3e2Bc54a,
      0xE73B2AEB8A9f360FB16F7D8Df721B1b40076Aa5E
    ];

    _lastTokenId = lastTokenId_;
    _mint(msg.sender, lastTokenId_);
    if (secondaryChain) {
      // if so, it is a bridged version of the token and cannot be minted by a manager
      _mintEnded = true;
    }
    for (uint256 i = 0; i < _teamWallets.length; i++) {
      _mint(_teamWallets[i], --lastTokenId_);
    }
    _baseTokenURI = "https://meta.everdragons2.com/e2gt/";
  }

  function _authorizeUpgrade(address newImplementation)
  internal
  onlyOwner
  override
  {}

  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
      internal
      override(ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable)
  {
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

  /*
  constructor(uint256 lastTokenId_, bool secondaryChain) ERC721Playable("Everdragons2 Genesis Token", "E2GT") {
    _lastTokenId = lastTokenId_;
    _mint(msg.sender, lastTokenId_);
    if (secondaryChain) {
      // if so, it is a bridged version of the token and cannot be minted by a manager
      _mintEnded = true;
    }
    for (uint256 i = 0; i < _teamWallets.length; i++) {
      _mint(_teamWallets[i], --lastTokenId_);
    }
    _baseTokenURI = "https://meta.everdragons2.com/e2gt/";
  }*/

  function isMinted(uint256 tokenId) external view override returns (bool) {
    return _isMinted[tokenId];
  }

  function lastTokenId() external view override returns (uint256) {
    return _lastTokenId;
  }

  function teamWallets() external view override returns (address[] memory) {
    return _teamWallets;
  }

  /*
  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal override(ERC721, ERC721Playable, ERC721Enumerable) {
    super._beforeTokenTransfer(_from, _to, _tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Playable, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
  */

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

  function mintingIsEnded() external view override returns(bool) {
    return _mintEnded;
  }

  function contractURI() public view returns (string memory) {
    return _baseURI();
  }

  // Wormhole

  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable returns (uint64 sequence) {
    require(_isApprovedOrOwner(_msgSender(), tokenID), "ERC721: transfer caller is not owner nor approved");
    burn(tokenID);
    return _wormholeTransferWithValue(tokenID, recipientChain, recipient, nonce, msg.value);
  }

  // Complete a transfer from Wormhole
  function wormholeCompleteTransfer(bytes memory encodedVm) public {
    (address to, uint256 tokenId) = _wormholeCompleteTransfer(encodedVm);
    // _isMinted is needed only during the drop sale. Not here
    _safeMint(to, tokenId);
  }

}
