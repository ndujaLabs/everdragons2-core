// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IWormhole.sol";
import "./libraries/BytesLib.sol";
import "./NFTStructs.sol";
import "./NFTGetters.sol";
import "./NFTSetters.sol";

contract WormholeERC721 is Ownable, NFTGetters, NFTSetters {
  using BytesLib for bytes;

  function wormholeSetup(uint16 chainId, address wormhole) public onlyOwner {
    // _setOwner(_msgSender());
    _setChainId(chainId);
    _setWormhole(wormhole);
  }

  function wormholeRegisterChain(uint16 chainId_, bytes32 bridgeContract_) public onlyOwner {
    _setBridgeImplementation(chainId_, bridgeContract_);
  }

  function _wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) internal returns (uint64 sequence) {
    //require(_isApprovedOrOwner(_msgSender(), tokenID), "ERC721: transfer caller is not owner nor approved");
    require(bridgeContracts(recipientChain) != 0, "ERC721: recipientChain not allowed");
    sequence = logTransfer(NFTStructs.Transfer({tokenID: tokenID, to: recipient, toChain: recipientChain}), msg.value, nonce);
    return sequence;
  }

  function logTransfer(
    NFTStructs.Transfer memory transfer,
    uint256 callValue,
    uint32 nonce
  ) internal returns (uint64 sequence) {
    bytes memory encoded = encodeTransfer(transfer);

    sequence = wormhole().publishMessage{value: callValue}(nonce, encoded, 15);
  }

  function _wormholeCompleteTransfer(bytes memory encodedVm) internal returns (address to, uint256 tokenId) {
    (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(encodedVm);

    require(valid, reason);
    require(verifyBridgeVM(vm), "invalid emitter");

    NFTStructs.Transfer memory transfer = parseTransfer(vm.payload);

    require(!isTransferCompleted(vm.hash), "transfer already completed");
    _setTransferCompleted(vm.hash);

    require(transfer.toChain == chainId(), "invalid target chain");

    // transfer bridged NFT to recipient
    address transferRecipient = address(uint160(uint256(transfer.to)));

    return (transferRecipient, transfer.tokenID);
  }

  function verifyBridgeVM(IWormhole.VM memory vm) internal view returns (bool) {
    if (bridgeContracts(vm.emitterChainId) == vm.emitterAddress) {
      return true;
    }

    return false;
  }

  function encodeTransfer(NFTStructs.Transfer memory transfer) internal pure returns (bytes memory encoded) {
    encoded = abi.encodePacked(uint8(1), transfer.tokenID, transfer.to, transfer.toChain);
  }

  function parseTransfer(bytes memory encoded) internal pure returns (NFTStructs.Transfer memory transfer) {
    uint256 index = 0;

    uint8 payloadID = encoded.toUint8(index);
    index += 1;

    require(payloadID == 1, "invalid Transfer");

    transfer.tokenID = encoded.toUint256(index);
    index += 32;

    transfer.to = encoded.toBytes32(index);
    index += 32;

    transfer.toChain = encoded.toUint16(index);
    index += 2;

    require(encoded.length == index, "invalid Transfer");
    return transfer;
  }

  function _wormholeGetContract(uint16 chainId) internal view returns (bytes32) {
    return bridgeContracts(chainId);
  }
}
