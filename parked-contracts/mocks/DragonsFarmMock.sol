// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IEverdragons2.sol";

contract DragonsFarmMock {
  IEverdragons2 public everdragons2;

  constructor(address everdragons2_) {
    everdragons2 = IEverdragons2(everdragons2_);
  }

  function mint(address recipient, uint256[] memory tokenIds) external {
    everdragons2.mint(recipient, tokenIds);
  }

  function mint(address[] memory recipients, uint256[] memory tokenIds) external {
    everdragons2.mint(recipients, tokenIds);
  }
}
