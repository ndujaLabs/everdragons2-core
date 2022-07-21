// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Everdragons2GenesisV3.sol";

contract StakingPoolMockV3 is IStakingPool {
  Everdragons2GenesisV3 public e2;

  constructor(address e2_) {
    e2 = Everdragons2GenesisV3(e2_);
  }

  function id() external pure returns (bytes32) {
    return keccak256("Everdragons2Pool");
  }

  function stakeEvd2(uint256 tokenId) external {
    e2.lock(tokenId);
  }

  function unstakeEvd2(uint256 tokenId) external {
    e2.unlock(tokenId);
  }
}
