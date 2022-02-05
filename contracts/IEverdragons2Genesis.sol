// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2, https://everdragons2.com

interface IEverdragons2Genesis {
  function setManager(address manager_) external;

  function mint(address recipient, uint256 tokenId) external;

  function updateBaseTokenURI(string memory uri) external;

  function freezeBaseTokenURI() external;

  function endMinting() external;

  function mintEnded() external view returns (bool);

}
