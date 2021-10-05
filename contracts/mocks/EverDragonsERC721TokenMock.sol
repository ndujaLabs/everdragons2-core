// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EverDragonsERC721TokenMock {
  mapping(uint256 => address) public tokens;

  function mintToken(address owner, uint256 tokenID) external {
    tokens[tokenID] = owner;
  }

  function ownerOf(uint256 tokenId) external view virtual returns (address) {
    return tokens[tokenId];
  }
}
