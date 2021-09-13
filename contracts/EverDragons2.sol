// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2, https://everdragons2.com

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IEverDragons2.sol";
import "./DragonsMaster.sol";

contract EverDragons2 is IEverDragons2, ERC721, Ownable {
  address public manager;

  string private _uri = "https://everdragons2.com/metadata/";

  modifier onlyManager() {
    require(_msgSender() == manager, "Forbidden");
    _;
  }

  constructor() ERC721("EverDragons2", "ED2") {}

  function setManager(address manager_) external override onlyOwner {
    require(manager == address(0), "Manager already set");
    manager = manager_;
  }

  function mint(address recipient, uint256[] memory tokenIds) external override onlyManager {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mint(recipient, tokenIds[i]);
    }
  }

  function mint(address[] memory recipients, uint256[] memory tokenIds) external override onlyManager {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mint(recipients[i], tokenIds[i]);
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _uri;
  }

  function updateBaseURI(string memory uri) external override onlyOwner {
    _uri = uri;
  }
}
