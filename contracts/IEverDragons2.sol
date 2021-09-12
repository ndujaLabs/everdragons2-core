// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEverDragons2 {
  function setManager(address manager_) external;

  function mint(address recipient, uint256[] memory tokenIds) external;

  function mint(address[] memory recipients, uint256[] memory tokenIds) external;

  function setBaseURI(string memory uri) external;
}
