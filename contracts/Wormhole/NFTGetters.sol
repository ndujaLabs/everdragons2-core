// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.2;

import "./interfaces/IWormhole.sol";
import "./NFTState.sol";

contract NFTGetters is NFTState {
  function isTransferCompleted(bytes32 hash) public view returns (bool) {
    return _state.completedTransfers[hash];
  }

  function bridgeContracts(uint16 chainId_) public view returns (bytes32) {
    return _state.bridgeImplementations[chainId_];
  }

  function wormhole() public view returns (IWormhole) {
    return IWormhole(_state.wormhole);
  }

  function chainId() public view returns (uint16) {
    return _state.chainId;
  }
}
