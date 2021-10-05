// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEverDragonsERC721Token {
  function ownerOf(uint256 tokenId) external view returns (address owner);
}
