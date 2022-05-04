// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2, https://everdragons2.com

import "./IEverdragons2Bridge.sol";

interface IEverdragons2Genesis {
  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  //  function airdrop(address[] memory recipients, uint256[] memory tokenIDs) external;

  // bridge

  function setBridge(IEverdragons2Bridge bridge_) external;

  function crossChainTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) external;

  function completeCrossChainTransfer(bytes memory encodedVm) external;

  function mint(
    address to,
    uint256 tokenID,
    bytes4 evm
  ) external;

  function burn(uint256 tokenID) external;

  function isStaked(uint256 tokenID) external view returns (bool);

  function setPool(address pool) external;

  function removePool(address pool) external;

  function hasStakes(address owner) external view returns (bool);

  function stake(uint256 tokenID) external;

  function unstake(uint256 tokenID) external;

  function unstakeIfRemovedPool(uint256 tokenID) external;

  function id() external view returns (bytes32);
}
