// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2, https://everdragons2.com

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMCIP1.sol";

contract ERC721CrossGameMCIP1 is IMCIP1, ERC721, ERC721Enumerable, Ownable {
  event PlatformApproved(address platform);

  mapping(uint256 => mapping(address => Metadata)) internal _metadata;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(_from, _to, _tokenId);
  }

//  function getInterfaceId() external view returns (bytes4) {
//    return type(IMCIP1).interfaceId;
//  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return interfaceId == type(IMCIP1).interfaceId || super.supportsInterface(interfaceId);
  }

  function metadataOf(uint256 _tokenId, address _game) public view override returns (Metadata memory) {
    return _metadata[_tokenId][_game];
  }

  function initMetadata(
    uint256 _tokenId,
    uint8 _version,
    uint8 _initialStatus,
    uint8[30] memory _initialAttributes
  ) external override returns (bool) {
    _metadata[_tokenId][_msgSender()] = Metadata(_version, _initialStatus, _initialAttributes);
    return true;
  }

  function updateAttributes(
    uint256 _tokenId,
    uint8[] memory _indexes,
    uint8[] memory _values
  ) public override returns (bool) {
    require(_indexes.length == _values.length, "inconsistent lengths");
    require(_metadata[_tokenId][_msgSender()].version > 0, "game not initialized");
    for (uint256 i = 0; i < _indexes.length; i++) {
      _metadata[_tokenId][_msgSender()].attributes[_indexes[i]] = _values[i];
    }
    return true;
  }

  function updateStatusProperty(
    uint256 _tokenId,
    uint256 _position,
    bool _newValue
  ) public override returns (bool) {
    require(_position < 8, "status bit out of range");
    require(_metadata[_tokenId][_msgSender()].version > 0, "game not initialized");
    uint256 newValue;
    if (_newValue) {
      newValue = (1 << _position) | _metadata[_tokenId][_msgSender()].status;
    } else {
      newValue = (255 & (~(1 << _position))) & _metadata[_tokenId][_msgSender()].status;
    }
    _metadata[_tokenId][_msgSender()].status = uint8(newValue);
    return true;
  }
}
