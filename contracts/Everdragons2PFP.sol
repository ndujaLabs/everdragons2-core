// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@ndujalabs/erc721subordinate/contracts/ERC721SubordinateUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Everdragons2PFP is OwnableUpgradeable, ERC721SubordinateUpgradeable, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(address everdragons2Genesis) public initializer {
    __ERC721Subordinate_init("Everdragons2 PFP", "E2PFP", everdragons2Genesis);
    __UUPSUpgradeable_init();
    __Ownable_init();
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override {}
}
