// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2, https://everdragons2.com

import "./IEverDragons2.sol";
import "./ERC721CrossGameMCIP1.sol";

contract EverDragons2 is IEverDragons2, ERC721CrossGameMCIP1 {
  using Address for address;
  address public manager;
  bool private _mintEnded;
  bool private _baseTokenURIFrozen;

  string private _baseTokenURI;

  modifier onlyManager() {
    require(manager != address(0) && _msgSender() == manager, "Forbidden");
    _;
  }

  modifier canMint() {
    require(!_mintEnded, "Minting ended");
    _;
  }

  constructor() ERC721CrossGameMCIP1("EverDragons2", "ED2") {
    _mint(msg.sender, 10001);
    _baseTokenURI = "https://everdragons2.com/metadata/ed2/";
  }

  function setManager(address manager_) external override onlyOwner canMint {
    require(manager_ != address(0), "Manager cannot be 0x0");
    manager = manager_;
  }

  function mint(address recipient, uint256[] memory tokenIds) external override onlyManager canMint {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mint(recipient, tokenIds[i]);
    }
  }

  function mint(address[] memory recipients, uint256[] memory tokenIds) external override onlyManager canMint {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mint(recipients[i], tokenIds[i]);
    }
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
}
