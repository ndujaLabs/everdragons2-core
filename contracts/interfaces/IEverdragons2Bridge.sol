// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>

interface IEverdragons2Bridge {
  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) external payable returns (uint64 sequence);

  function wormholeCompleteTransfer(bytes memory encodedVm) external;

  function id() external view returns (bytes32);
}
