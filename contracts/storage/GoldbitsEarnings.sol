// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Everdragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/access/Ownable.sol";

//import "hardhat/console.sol";

// A contract to allow people to buy on Ethereum and receive tokens on Polygon
contract GoldbitsEarnings is Ownable {
  struct Earning {
    uint8 id;
    uint24 goldbits;
    uint8 totalWins;
    uint8 totalTweets;
  }

  mapping(address => Earning) public earnings;
  address[] public earners;
  bool public frozen;

  constructor() {}

  function save(
    address[] calldata earner,
    Earning[] calldata data
  ) external onlyOwner {
    require(!frozen, "Frozen");
    for (uint256 i = 0; i < earner.length; i++) {
      earnings[earner[i]] = Earning({id: data[i].id, goldbits: data[i].goldbits, totalWins: data[i].totalWins, totalTweets: data[i].totalTweets});
      earners.push(earner[i]);
    }
  }

  function freeze() external onlyOwner {
    frozen = true;
  }

  function total() external view returns(uint) {
    return earners.length;
  }
}
