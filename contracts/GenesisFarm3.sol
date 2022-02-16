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

contract GenesisFarm3 is Ownable, IManager {
  using SafeMath for uint256;

  event OperatorSet(address operator);

  IEverdragons2GenesisExtended public everdragons2Genesis;

  bytes32 public root;
  uint256 public nextTokenId;
  uint256 public maxForSale;
  uint256 public proceedsBalance;
  uint256 public price;
  address public operator;

  uint256 public maxClaimable;
  uint256 private _lastUnclaimed;
  mapping(uint256 => bool) private _claimed;
  bool public claimingEnded;

  constructor(
    IEverdragons2GenesisExtended everdragons2_,
    uint256 maxForSale_,
    uint256 maxClaimable_,
    uint256 price_,
    address operator_
  ) {
    everdragons2Genesis = everdragons2_;
    require(everdragons2Genesis.mintEnded() == false, "Not an E2 token");
    uint256 temporaryTotalSupply = everdragons2Genesis.totalSupply();
    maxForSale = maxForSale_;
    maxClaimable = maxClaimable_;
    nextTokenId = maxClaimable + temporaryTotalSupply + 1;
    price = price_;
    setOperator(operator_);
  }

  function setOperator(address operator_) public onlyOwner {
    require(operator_ != address(0), "operator cannot be 0x0");
    operator = operator_;
    emit OperatorSet(operator);
  }

  function isManager() external pure override returns (bool) {
    return true;
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

  function deliverCrossChainPurchase(address buyer, uint quantity) external {
    require(operator != address(0) && _msgSender() == operator, "Sender not the operator");
    require(nextTokenId + quantity - 1 <= maxForSale + maxClaimable, "Not enough tokens left");
    uint256 nextId = nextTokenId;
    for (uint256 i = 0; i < quantity; i++) {
      everdragons2Genesis.mint(buyer, nextId++);
    }
    require(nextId <= maxForSale + maxClaimable + 1, "Id out of range");
    nextTokenId = nextId;
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
