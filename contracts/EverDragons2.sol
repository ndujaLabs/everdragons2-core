// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./IEverDragons2.sol";
import "./DragonsMaster.sol";

contract EverDragons2 is IEverDragons2, ERC721, Ownable {
  address public manager;
  string private _uri;

  modifier onlyManager() {
    require(_msgSender() == manager, "Forbidden");
    _;
  }

  constructor() ERC721("EverDragons2", "ED2") {
    setBaseURI("https://everdragons2.com/metadata/");
  }

  function setManager(address manager_) external override onlyOwner {
    require(manager == address(0), "Manager already set");
    manager = manager_;
  }

  function mint(address recipient, uint256[] memory tokenIds) external override onlyManager {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mint(recipient, tokenIds[i]);
    }
  }

  function mint(address[] memory recipients, uint256[] memory tokenIds) external override onlyManager {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _mint(recipients[i], tokenIds[i]);
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _uri;
  }

  function setBaseURI(string memory uri) public override onlyOwner {
    // It is an emergency function in case something bad happens to the domain.
    // In the future, the owner could renounce to the ownership making
    // the NFT immutable
    _uri = uri;
  }
}
