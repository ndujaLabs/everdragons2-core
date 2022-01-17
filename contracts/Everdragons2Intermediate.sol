// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

// Authors: Francesco Sullo <francesco@sullo.co>
//          Emanuele Cesena <emanuele@ndujalabs.com>
// Everdragons2, https://everdragons2.com

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@ndujalabs/wormhole721/contracts/Wormhole721Upgradeable.sol";

import "hardhat/console.sol";

abstract contract Everdragons2Intermediate is
  PausableUpgradeable,
  OwnableUpgradeable,
  UUPSUpgradeable,
  Wormhole721Upgradeable
{

  function __Everdragons2Intermediate_init() internal virtual initializer {
    __Ownable_init();
    __Pausable_init();
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

}
