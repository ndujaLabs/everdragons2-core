// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Everdragons2GenesisV2.sol";

contract StakingPoolMock is IStakingPool {
  Everdragons2GenesisV2 public e2;

  constructor(address e2_) {
    e2 = Everdragons2GenesisV2(e2_);
  }

  function id() external pure returns (bytes32) {
    return keccak256("Everdragons2Pool");
  }

  function stakeEvd2(uint256 tokenId) external {
    e2.stake(tokenId);
  }

  function unstakeEvd2(uint256 tokenId) external {
    e2.unstake(tokenId);
  }
}
