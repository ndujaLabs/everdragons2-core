// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// Everdragons2, https://everdragons2.com

import "../Everdragons2GenesisV2.sol";

//import "hardhat/console.sol";

contract Everdragons2GenesisV2Mock is
  Everdragons2GenesisV2
{

  function endMint() external {
    _mintEnded = true;
  }

}
