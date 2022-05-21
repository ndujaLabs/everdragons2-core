// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// Everdragons2, https://everdragons2.com

import "../Everdragons2GenesisV2.sol";

//import "hardhat/console.sol";

contract Everdragons2GenesisV2Mock is Everdragons2GenesisV2 {
  // in the contract _mintEnded is private, so we need a new variable here
  bool private _mintEnded2;

  function endMinting() external onlyOwner {
    _mintEnded2 = true;
  }

  function mintEnded() public view override returns (bool) {
    return _mintEnded2;
  }
}
