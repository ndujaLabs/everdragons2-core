// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2, https://everdragons2.com

interface IEverdragons2 {
  function setManager(address manager_) external;

  function mint(address recipient, uint256[] memory tokenIds) external;

  function mint(address[] memory recipients, uint256[] memory tokenIds) external;

  function mint(address recipient, uint256 tokenId) external;

  function makeItSellable() external;

  function updateBaseTokenURI(string memory uri) external;

  function freezeBaseTokenURI() external;

  function endMinting() external;

  function mintingIsEnded() external view returns (bool);

  function lastTokenId() external view returns (uint256);

  function teamWallets() external view returns (address[] memory);

  function isMinted(uint256 tokenId) external view returns (bool);
}
