// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2, https://everdragons2.com

interface IEverdragons2GenesisBridged {
  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;
}
