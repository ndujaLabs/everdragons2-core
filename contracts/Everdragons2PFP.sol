// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Author: Francesco Sullo, francesco@sullo.co
// January 1st, 2023

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@ndujalabs/erc721subordinate/contracts/ERC721EnumerableSubordinateUpgradeable.sol";
import "./Version.sol";

contract Everdragons2PFP is Version, ERC721EnumerableSubordinateUpgradeable, OwnableUpgradeable {

  event FrozeContract();
  error ContractHasBeenFrozen();

  string private _baseTokenURI;
  bool public frozen;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(address everdragons2Genesis) public initializer {
    __Ownable_init();
    __ERC721EnumerableSubordinate_init("Everdragons2 PFP", "E2PFP", everdragons2Genesis);
    _baseTokenURI = "https://img.everdragons2.com/e2pfp/";
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override {
    if (frozen) revert ContractHasBeenFrozen();
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external onlyOwner {
    if (frozen) revert ContractHasBeenFrozen();
    _baseTokenURI = uri;
  }

  // Since ERC721Subordinate is a recent, un-audited proposal, we keep it initially
  // upgradeable. freeze will allow us to freeze the contract, and make it no more
  // upgradeable, when everything is written in stone.
  function freeze() external onlyOwner {
    // BE CAREFUL.
    // This makes the contract not upgradeable anymore, and cannot be reverted.
    frozen = true;
  }
}
