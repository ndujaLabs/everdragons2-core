// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.3;

//import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import "./interfaces/IWormhole.sol";
import "./libraries/BytesLib.sol";
import "./NFTStructs.sol";
import "./NFTGetters.sol";
import "./NFTSetters.sol";
import "./IWormholeERC721.sol";

// notice that this is not an ERC721
// but it is supposed to be extended by an ERC721
contract WormholeERC721Upgradeable is OwnableUpgradeable, NFTGetters, NFTSetters, IWormholeERC721, ERC165Upgradeable {
  using BytesLib for bytes;

//  function getIWormholeERC721InterfaceId() external pure returns(bytes4) {
//    return type(IWormholeERC721).interfaceId;
//  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IWormholeERC721).interfaceId || super.supportsInterface(interfaceId);
  }

  function wormholeInit(uint16 chainId, address wormhole) public override onlyOwner {
    _setChainId(chainId);
    _setWormhole(wormhole);
  }

  function wormholeRegisterContract(uint16 chainId_, bytes32 nftContract_) public override onlyOwner {
    _setNftContract(chainId_, nftContract_);
  }

  function wormholeGetContract(uint16 chainId) public view override returns (bytes32) {
    return nftContract(chainId);
  }

  function _wormholeCompleteTransfer(bytes memory encodedVm) internal returns (address to, uint256 tokenId) {
    (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(encodedVm);

    require(valid, reason);
    require(_verifyNftContractVM(vm), "invalid emitter");

    NFTStructs.Transfer memory transfer = _parseTransfer(vm.payload);

    require(!isTransferCompleted(vm.hash), "transfer already completed");
    _setTransferCompleted(vm.hash);

    require(transfer.toChain == chainId(), "invalid target chain");

    // transfer bridged NFT to recipient
    address transferRecipient = address(uint160(uint256(transfer.to)));

    return (transferRecipient, transfer.tokenId);
  }

    function getInterfaceId2() external view returns(bytes4) {
      return type(IWormholeERC721).interfaceId;
    }


  function _wormholeTransfer(
    uint256 tokenId,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) internal returns (uint64 sequence) {
    // TODO msg.value - Wormhole fees
    return _wormholeTransferWithValue(tokenId, recipientChain, recipient, nonce, msg.value);
  }

  function _wormholeTransferWithValue(
    uint256 tokenId,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce,
    uint256 value
  ) internal returns (uint64 sequence) {
    require(nftContract(recipientChain) != 0, "ERC721: recipientChain not allowed");
    sequence = _logTransfer(NFTStructs.Transfer({tokenId: tokenId, to: recipient, toChain: recipientChain}), value, nonce);
    return sequence;
  }

  function _logTransfer(
    NFTStructs.Transfer memory transfer,
    uint256 callValue,
    uint32 nonce
  ) internal returns (uint64 sequence) {
    bytes memory encoded = _encodeTransfer(transfer);
    sequence = wormhole().publishMessage{value: callValue}(nonce, encoded, 15);
  }

  function _verifyNftContractVM(IWormhole.VM memory vm) internal view returns (bool) {
    if (nftContract(vm.emitterChainId) == vm.emitterAddress) {
      return true;
    }
    return false;
  }

  function _encodeTransfer(NFTStructs.Transfer memory transfer) internal pure returns (bytes memory encoded) {
    encoded = abi.encodePacked(uint8(1), transfer.tokenId, transfer.to, transfer.toChain);
  }

  function _parseTransfer(bytes memory encoded) internal pure returns (NFTStructs.Transfer memory transfer) {
    uint256 index = 0;

    uint8 payloadId = encoded.toUint8(index);
    index += 1;

    require(payloadId == 1, "invalid Transfer");

    transfer.tokenId = encoded.toUint256(index);
    index += 32;

    transfer.to = encoded.toBytes32(index);
    index += 32;

    transfer.toChain = encoded.toUint16(index);
    index += 2;

    require(encoded.length == index, "invalid Transfer");
    return transfer;
  }

  //
  //
  // the following MUST be implemented and overridden

  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable override returns (uint64 sequence) {
    return 0;
  }

  function wormholeCompleteTransfer(bytes memory encodedVm) public override {
  }
}
