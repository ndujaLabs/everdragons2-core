// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EverDragonsERC721TokenMock {

  mapping(uint => address) internal tokens;

  function mintToken(address owner, uint tokenID) external {
    tokens[tokenID] = owner;
  }

  function ownerOf(uint256 tokenId) external view virtual returns (address) {
    return tokens[tokenId];
  }
}
