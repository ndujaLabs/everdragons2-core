// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEverdragons2Genesis.sol";

contract FarmMock is Ownable {
  IEverdragons2Genesis public e2;

  constructor(address e2_) {
    e2 = IEverdragons2Genesis(e2_);
  }

  function mint(address recipient, uint256 tokenId) external onlyOwner {
    e2.mint(recipient, tokenId);
  }
}
