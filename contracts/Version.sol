// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Version {
  function version() public pure virtual returns (string memory) {
    // this must be aligned with the version in package.json
    return "0.4.0";
  }
}




