// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2, https://everdragons2.com

interface IEverdragons2GenesisBridged {

  function updateBaseTokenURI(string memory uri) external;

  function freezeBaseTokenURI() external;

}
