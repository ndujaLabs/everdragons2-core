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
import "@ndujalabs/wormhole-tunnel/contracts/WormholeTunnelUpgradeable.sol";

import "./interfaces/IEverdragons2Genesis.sol";
import "./interfaces/IManager.sol";

//import "hardhat/console.sol";

contract Everdragons2Genesis is
  IEverdragons2Genesis,
  Initializable,
  ERC721Upgradeable,
  ERC721PlayableUpgradeable,
  ERC721EnumerableUpgradeable,
  WormholeTunnelUpgradeable
{
  bool private _mintEnded;
  bool private _baseTokenURIFrozen;
  string private _baseTokenURI;

  address public manager;
  mapping(uint256 => bool) public staked;

  modifier onlyManager() {
    require(manager != address(0) && _msgSender() == manager, "Forbidden");
    _;
  }

  modifier canMint() {
    require(!_mintEnded, "Minting ended");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize() public initializer {
    __WormholeTunnel_init();
    __ERC721_init("Everdragons2 Genesis Token", "EVD2");
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
    override(WormholeTunnelUpgradeable, ERC721Upgradeable, ERC721PlayableUpgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function setManager(address manager_) external override onlyOwner canMint {
    require(manager_ != address(0), "Manager cannot be 0x0");
    require(IManager(manager_).isManager(), "Not a manager");
    manager = manager_;
  }

  function mint(address recipient, uint256 tokenId) public override onlyManager canMint {
    _safeMint(recipient, tokenId);
  }

  function endMinting() external override onlyOwner {
    _mintEnded = true;
  }

  function mintEnded() external view override returns (bool) {
    return _mintEnded;
  }

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

  function contractURI() public view returns (string memory) {
    return string(abi.encodePacked(_baseTokenURI, "0"));
  }

  // staking

  function getApproved(uint256 tokenId) public view override returns (address) {
    if (staked[tokenId]) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
    return false;
  }

  function stake(uint256 tokenID) external onlyManager {
    // will revert if token does not exist
    ownerOf(tokenID);
    staked[tokenID] = true;
  }

  function unstake(uint256 tokenID) external onlyManager {
    // will revert if token does not exist
    ownerOf(tokenID);
    delete staked[tokenID];
  }

  // wormhole

  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable override returns (uint64 sequence) {
    require(!staked[tokenID], "Token is staked");
    require(_isApprovedOrOwner(_msgSender(), tokenID), "Transfer caller is not owner nor approved");
    _burn(tokenID);
    return _wormholeTransferWithValue(tokenID, recipientChain, recipient, nonce, msg.value);
  }

  // Complete a transfer from Wormhole
  function wormholeCompleteTransfer(bytes memory encodedVm) public override {
    (address to, uint256 tokenId) = _wormholeCompleteTransfer(encodedVm);
    _safeMint(to, tokenId);
  }

  uint256[50] private __gap;
}
