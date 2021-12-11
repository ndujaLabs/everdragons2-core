// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2, https://everdragons2.com

interface IEverDragons2 {
  function setManager(address manager_) external;

  function mint(address recipient, uint256[] memory tokenIds) external;

  function mint(address[] memory recipients, uint256[] memory tokenIds) external;

  function updateBaseTokenURI(string memory uri) external;

  function freezeBaseTokenURI() external;

  function endMinting() external;
}
