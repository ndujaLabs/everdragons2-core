// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2, https://everdragons2.com

interface IEverdragons2GenesisExtended {
  function setManager(address manager_) external;

  function mint(address recipient, uint256 tokenId) external;

  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  function endMinting() external;

  function mintEnded() external view returns (bool);

  function totalSupply() external view returns (uint256);

  function ownerOf(uint256 tokenId) external view returns (address owner);
}
