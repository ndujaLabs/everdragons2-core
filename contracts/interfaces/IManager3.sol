// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface IManager3 {
  function isManager() external pure returns (bool);
  function hasManagerRole() external view returns (bool);
}
