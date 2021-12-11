// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.2;

import "./NFTState.sol";

contract NFTSetters is NFTState {
  function _setOwner(address owner_) internal {
    _state.owner = owner_;
  }

  function _setWormhole(address wh) internal {
    _state.wormhole = payable(wh);
  }

  function _setChainId(uint16 chainId_) internal {
    _state.chainId = chainId_;
  }

  function _setTransferCompleted(bytes32 hash) internal {
    _state.completedTransfers[hash] = true;
  }

  function _setBridgeImplementation(uint16 chainId, bytes32 bridgeContract) internal {
    _state.bridgeImplementations[chainId] = bridgeContract;
  }
}
