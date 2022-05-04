// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Authors: Francesco Sullo <francesco@sullo.co>

import "@ndujalabs/wormhole-tunnel/contracts/WormholeTunnel.sol";

import "./interfaces/IEverdragons2Genesis.sol";

//import "hardhat/console.sol";

contract Everdragons2Bridge is WormholeTunnel {
  IEverdragons2Genesis public everdragons2Genesis;

  modifier onlyEverdragons() {
    require(address(everdragons2Genesis) == _msgSender(), "Forbidden");
    _;
  }

  constructor(IEverdragons2Genesis everdragons2_) {
    require(everdragons2_.id() == keccak256("Everdragons2Genesis"), "Not an Everdragons2 NFT");
    everdragons2Genesis = everdragons2_;
  }

  function id() external view returns (bytes32) {
    return keccak256("Everdragons2Bridge");
  }

  function wormholeTransfer(
    uint256 tokenID,
    uint16 recipientChain,
    bytes32 recipient,
    uint32 nonce
  ) public payable override onlyEverdragons returns (uint64 sequence) {
    everdragons2Genesis.burn(tokenID);
    return _wormholeTransferWithValue(tokenID, recipientChain, recipient, nonce, msg.value);
  }

  // Complete a transfer from Wormhole
  function wormholeCompleteTransfer(bytes memory encodedVm) public override {
    (address to, uint256 tokenId) = _wormholeCompleteTransfer(encodedVm);
    bytes4 evm = bytes4(keccak256(encodedVm));
    everdragons2Genesis.mint(to, tokenId, evm);
  }
}
