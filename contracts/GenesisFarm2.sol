// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IEverdragons2GenesisExtended.sol";
import "./interfaces/IManager.sol";

import "hardhat/console.sol";

contract GenesisFarm2 is Ownable, IManager {
  using SafeMath for uint256;

  IEverdragons2GenesisExtended public everdragons2Genesis;

  bytes32 public root;
  uint256 public nextTokenId;
  uint256 public maxForSale;
  uint256 public proceedsBalance;
  uint256 public price;
  uint256 public extraTokens;

  uint256 public maxClaimable;
  uint256 private _lastUnclaimed;
  mapping(uint256 => bool) private _claimed;
  bool public claimingEnded;

  mapping(address => uint256) public firstBuyersBalance;
  address[] public firstBuyers;

  constructor(
    IEverdragons2GenesisExtended everdragons2_,
    uint256 maxForSale_,
    uint256 maxClaimable_,
    uint256 price_,
    uint256 extraTokens_
  ) {
    everdragons2Genesis = everdragons2_;
    require(everdragons2Genesis.mintEnded() == false, "Not an E2 token");
    uint256 temporaryTotalSupply = everdragons2Genesis.totalSupply();
    maxForSale = maxForSale_;
    maxClaimable = maxClaimable_;
    extraTokens = extraTokens_;
    nextTokenId = maxClaimable + temporaryTotalSupply + 1;
    price = price_;
    for (uint256 i = maxClaimable + 1; i < maxClaimable + 1 + temporaryTotalSupply; i++) {
      address buyer = everdragons2Genesis.ownerOf(i);
      if (firstBuyersBalance[buyer] == 0) {
        firstBuyers.push(buyer);
      }
      firstBuyersBalance[buyer] += 1;
    }
  }

  function totalFirstBuyers() external view returns (uint256) {
    return firstBuyers.length;
  }

  function isManager() external pure override returns (bool) {
    return true;
  }

  function giveExtraTokens(uint256 index, uint256 max) external onlyOwner {
    address buyer = firstBuyers[index];
    uint256 remaining = firstBuyersBalance[buyer];
    uint256 nextId = nextTokenId;
    if (remaining > 0) {
      if (remaining > max) {
        remaining = max;
      }
      for (uint256 j = 0; j < remaining; j++) {
        for (uint256 k = 0; k < extraTokens; k++) {
          everdragons2Genesis.mint(buyer, nextId++);
        }
        firstBuyersBalance[buyer]--;
      }
      nextTokenId = nextId;
    }
  }

  function claimRemainingTokens(address treasury, uint256 limit) external onlyOwner {
    require(claimingEnded, "Claiming not ended yet");
    uint256 j = 0;
    uint256 k = 0;
    for (uint256 i = _lastUnclaimed + 1; i <= maxClaimable; i++) {
      if (!_claimed[i]) {
        j++;
        k = i;
        everdragons2Genesis.mint(treasury, i);
      }
      if (j == limit) {
        break;
      }
    }
    _lastUnclaimed = k;
  }

  function setRoot(bytes32 root_) external onlyOwner {
    require(root_ != 0, "Empty root");
    root = root_;
  }

  function updatePrice(uint256 price_) external onlyOwner {
    price = price_;
  }

  function endClaiming() external onlyOwner {
    claimingEnded = true;
  }

  function encodeLeaf(address recipient, uint256[] calldata tokenIds) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(recipient, tokenIds));
  }

  function claimWhitelistedTokens(uint256[] calldata tokenIds, bytes32[] calldata proof) external {
    require(root != 0, "Root not set yet");
    require(!claimingEnded, "Claiming ended");
    bytes32 leaf = encodeLeaf(_msgSender(), tokenIds);
    require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(tokenIds[i] <= maxClaimable, "Id out of range");
      _claimed[tokenIds[i]] = true;
      everdragons2Genesis.mint(_msgSender(), tokenIds[i]);
    }
  }

  function buyTokens(uint256 quantity) external payable {
    require(nextTokenId + quantity - 1 <= maxForSale + maxClaimable, "Not enough tokens left");
    require(msg.value >= price.mul(quantity), "Insufficient payment");
    uint256 nextId = nextTokenId;
    for (uint256 i = 0; i < quantity; i++) {
      everdragons2Genesis.mint(_msgSender(), nextId++);
    }
    require(nextId <= maxForSale + maxClaimable + 1, "Id out of range");
    nextTokenId = nextId;
    proceedsBalance += msg.value;
  }

  function withdrawProceeds(address beneficiary, uint256 amount) public onlyOwner {
    if (amount == 0) {
      amount = proceedsBalance;
    }
    require(amount <= proceedsBalance, "Insufficient funds");
    proceedsBalance -= amount;
    (bool success, ) = beneficiary.call{value: amount}("");
    require(success);
  }

  function updateMaxForSale(uint256 maxForSale_) external onlyOwner {
    require(maxForSale_ != maxForSale, "Not a change");
    maxForSale = maxForSale_;
  }
}
