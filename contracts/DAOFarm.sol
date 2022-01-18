// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEverdragons2.sol";

import "hardhat/console.sol";

contract DAOFarm is Ownable {

  uint private _nextTokenId = 1;
  mapping(address => uint8) public got;
  IEverdragons2 public everdragons2;

  constructor(address everdragons2_) {
    everdragons2 = IEverdragons2(everdragons2_);
  }

  function mintInitial150Tokens(uint256 quantity) external onlyOwner {
    uint256 nextId = _nextTokenId;
    // most likely it can mint 40 at time
    for (uint256 i = 0; i < quantity; i++) {
      if (nextId == 151) {
        break;
      }
      everdragons2.mint(msg.sender, nextId++);
    }
    _nextTokenId = nextId;
  }

  function giveAway350Tokens(address[] memory recipients, uint256[] memory quantities) external onlyOwner {
    require(recipients.length == quantities.length, "Inconsistent lengths");
    uint256 nextId = _nextTokenId;
    for (uint256 i = 0; i < recipients.length; i++) {
      if (got[recipients[i]] == 0) {
        require(nextId + quantities[i] - 1 < 501, "Not enough DAO tokens left");
        for (uint j = 0; j < quantities[i]; j++) {
          everdragons2.mint(recipients[i], nextId++);
        }
        // to avoid giving someone tokens more times by mistake
        got[recipients[i]] = uint8(quantities[i]);
      }
    }
    _nextTokenId = nextId;
  }
}
