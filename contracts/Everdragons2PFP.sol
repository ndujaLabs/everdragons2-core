// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Author: Francesco Sullo, francesco@sullo.co
// January 1st, 2023

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@ndujalabs/erc721subordinate/contracts/upgradeables/ERC721SubordinateUpgradeable.sol";

contract Everdragons2PFP is OwnableUpgradeable, ERC721SubordinateUpgradeable, UUPSUpgradeable {

  event FrozeContract();
  error ContractHasBeenFrozen();

  string private _baseTokenURI;
  bool public frozen;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  function initialize(address everdragons2Genesis) public initializer {
    __Ownable_init();
    __ERC721Subordinate_init("Everdragons2 PFP", "E2PFP", everdragons2Genesis);
    __UUPSUpgradeable_init();
    _baseTokenURI = "https://img.everdragons2.com/e2pfp/";
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override {
    if (frozen) revert ContractHasBeenFrozen();
  }

  function version() public pure virtual returns (string memory) {
    // this should be aligned with the version in package.json
    return "0.4.2";
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

  // anyone can call this function to emit the initial transfer events
  function emitInitialTransfers(uint fromId, uint toId) external {
    for (uint i = fromId; i <= toId; i++) {
      try this.emitInitialTransfer(i) {
      } catch {
        // we ignore the error
      }
    }
  }
}
