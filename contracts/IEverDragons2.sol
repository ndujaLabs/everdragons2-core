// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2, https://everdragons2.com

interface IEverDragons2 {
  function setManager(address manager_) external;

  function mint(address recipient, uint256[] memory tokenIds) external;

  function mint(address[] memory recipients, uint256[] memory tokenIds) external;

  function mint(address recipient, uint256 tokenId) external;

  function updateBaseTokenURI(string memory uri) external;

  function freezeBaseTokenURI() external;

  function endMinting() external;

  function mintingIsEnded() external view returns(bool);

  function lastTokenId() external view returns (uint256);

  function teamWallets() external view returns (address[] memory);

  function isMinted(uint256 tokenId) external view returns (bool);
}
