// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../IEverdragons2.sol";

contract DragonsFarmMock {
  IEverdragons2 public everDragons2;

  constructor(address everDragons2_) {
    everDragons2 = IEverdragons2(everDragons2_);
  }

  function mint(address recipient, uint256[] memory tokenIds) external {
    everDragons2.mint(recipient, tokenIds);
  }

  function mint(address[] memory recipients, uint256[] memory tokenIds) external {
    everDragons2.mint(recipients, tokenIds);
  }
}
