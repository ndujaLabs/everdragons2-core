// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2, https://everdragons2.com

contract EverDragons2 is ERC721, Ownable {
  address public manager;

  modifier onlyManager() {
    require(_msgSender() == manager, "Forbidden");
    _;
  }

  constructor() ERC721("EverDragons2", "ED2") {
  }

  function setManager(address manager_) external onlyOwner {
    require(manager == address(0), "Manager already set");
    manager = manager_;
  }

  function mintAndTransfer(address recipient, uint256[] memory tokenIds) external onlyManager {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mintAndTransfer(recipient, tokenIds[i]);
    }
  }

  function mintAndTransfer(address[] memory recipients, uint256[] memory tokenIds) external onlyManager {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mintAndTransfer(recipients[i], tokenIds[i]);
    }
  }

  function _mintAndTransfer(address recipient, uint256 tokenId) internal {
      _mint(owner(), tokenId);
      _transfer(owner(), recipient, tokenId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://everdragons2.com/metadata/";
  }
}
