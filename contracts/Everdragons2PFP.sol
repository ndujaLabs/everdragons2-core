// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@ndujalabs/erc721subordinate/contracts/ERC721EnumerableSubordinateUpgradeable.sol";
//import "../subordinate/contracts/ERC721EnumerableSubordinateUpgradeable.sol";

contract Everdragons2PFP is ERC721EnumerableSubordinateUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(address everdragons2Genesis) public initializer {
    __ERC721EnumerableSubordinateUpgradeable_init("Everdragons2 PFP", "E2PFP", everdragons2Genesis);
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override {}
}
