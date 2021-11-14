// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMCIP1.sol";

contract ERC721WithMCIP1 is IMCIP1, ERC721, ERC721Enumerable, Ownable {
  event PlatformApproved(address platform);

  mapping(uint256 => Metadata) internal _metadata;

  uint8 internal _firstMutable;
  uint8 internal _lastMutable;

  mapping(address => bool) internal _platforms;

  // for version 1 of the MCIP-1, it must be 2
  uint256 public constant MAX_STATUS_SHIFT_POSITION = 2;

  modifier onlyApprovedPlatform(uint256 _tokenId) {
    require(_platforms[_msgSender()], "not an approved platform");
    require(_exists(_tokenId), "operator query for nonexistent token");
    address owner = ERC721.ownerOf(_tokenId);
    require(getApproved(_tokenId) == _msgSender() || isApprovedForAll(owner, _msgSender()), "spender not approved");
    _;
  }

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    if (_exists(_tokenId)) {
      require(_metadata[_tokenId].status & (1 << 1) == 1 << 1, "token not transferable");
      require(_to != address(0) || _metadata[_tokenId].status & (1 << 2) == 1 << 2, "token not burnable");
    }
    // else minting a new token
    super._beforeTokenTransfer(_from, _to, _tokenId);
  }

//  function getInterfaceId() external view returns (bytes4) {
//    return type(IMCIP1).interfaceId;
//  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return interfaceId == type(IMCIP1).interfaceId || super.supportsInterface(interfaceId);
  }

  // approve a new game to manage the NFT's mutable attributes
  function approvePlatform(address _platform) external onlyOwner {
    require(_platform != address(0), "address 0x0 not allowed");
    _platforms[_platform] = true;
    emit PlatformApproved(_platform);
  }

  // return the index of first mutable attribute
  function firstMutable() public view returns (uint8) {
    return _firstMutable;
  }

  // return the index of last mutable attribute
  function lastMutable() public view returns (uint8) {
    return _lastMutable;
  }

  function metadataOf(uint256 _tokenId) public view override returns (Metadata memory) {
    return _metadata[_tokenId];
  }

  // We have only one version, so _tokenId is ignored
  // solhint-disable-next-line
  function isAttributeMutable(uint256 _tokenId, uint8 _attributeIndex) public view override returns (bool) {
    return _attributeIndex >= _firstMutable && _attributeIndex <= _lastMutable;
  }

  function _initMetadata(
    uint256 _tokenId,
    uint8 _version,
    uint8 _initialStatus,
    uint8[30] memory _initialAttributes
  ) internal returns (bool) {
    require(_version == 1, "version not supported");
    _metadata[_tokenId] = Metadata(_version, _initialStatus, _initialAttributes);
    return true;
  }

  function updateAttributes(
    uint256 _tokenId,
    uint8[] memory _indexes,
    uint8[] memory _values
  ) public override onlyApprovedPlatform(_tokenId) returns (bool) {
    require(_indexes.length == _values.length, "inconsistent lengths");
    for (uint256 i = 0; i < _indexes.length; i++) {
      require(isAttributeMutable(_tokenId, _indexes[i]), "immutable attributes can not be updated");
      _metadata[_tokenId].attributes[_indexes[i]] = _values[i];
    }
    return true;
  }

  function updateStatus(
    uint256 _tokenId,
    uint256 _shiftPosition,
    bool _newValue
  ) public override onlyApprovedPlatform(_tokenId) returns (bool) {
    require(_shiftPosition <= MAX_STATUS_SHIFT_POSITION, "status bit out of range");
    uint256 newValue;
    if (_newValue) {
      newValue = (1 << _shiftPosition) | _metadata[_tokenId].status;
    } else {
      newValue = (255 & (~(1 << _shiftPosition))) & _metadata[_tokenId].status;
    }
    _metadata[_tokenId].status = uint8(newValue);
    return true;
  }
}
