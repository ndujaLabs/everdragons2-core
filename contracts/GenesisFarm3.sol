// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IEverdragons2GenesisExtended.sol";
import "./interfaces/IManager3.sol";

import "hardhat/console.sol";

contract GenesisFarm3 is Ownable, IManager3 {
  using SafeMath for uint256;

  event OperatorSet(address operator);

  IEverdragons2GenesisExtended public everdragons2Genesis;

  bytes32 public root;
  uint256 public nextTokenId;
  uint256 public maxForSale;
  uint256 public proceedsBalance;
  uint256 public price;
  uint256 public saleClosedAt;
  address public operator;
  mapping(uint16 => bool) public usedNonces;

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
    closeSale(maxClaimable_ + maxForSale_ - (getChainId() == 137 ? 100 : 50));
  }

  function setOperator(address operator_) public onlyOwner {
    require(operator_ != address(0), "operator cannot be 0x0");
    operator = operator_;
    emit OperatorSet(operator);
  }

  function isManager() external pure override returns (bool) {
    return true;
  }

  function hasManagerRole() external view override returns (bool) {
    return everdragons2Genesis.manager() == address(this);
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

  function endClaiming() external onlyOwner {
    claimingEnded = true;
  }

  function closeSale(uint256 saleClosedAt_) public onlyOwner {
    require(saleClosedAt_ >= nextTokenId && saleClosedAt_ < maxClaimable + maxForSale, "Out of range");
    saleClosedAt = saleClosedAt_;
  }

  function encodeLeaf(address recipient, uint256[] calldata tokenIds) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(recipient, tokenIds));
  }

  function claimWhitelistedTokens(uint256[] calldata tokenIds, bytes32[] calldata proof) external {
    _claimWhitelistedTokens(_msgSender(), tokenIds, proof);
  }

  function delegatedClaimWhitelistedTokens(
    address recipient,
    uint256[] calldata tokenIds,
    bytes32[] calldata proof
  ) external onlyOwner {
    _claimWhitelistedTokens(recipient, tokenIds, proof);
  }

  function batchDelegatedClaimWhitelistedTokens(
    address[] memory recipients,
    uint256[][] calldata tokenIds,
    bytes32[][] calldata proof
  ) external onlyOwner {
    for (uint256 i = 0; i < recipients.length; i++) {
      _claimWhitelistedTokens(recipients[i], tokenIds[i], proof[i]);
    }
  }

  function _claimWhitelistedTokens(
    address recipient,
    uint256[] calldata tokenIds,
    bytes32[] calldata proof
  ) internal {
    require(root != 0, "Root not set yet");
    require(!claimingEnded, "Claiming ended");
    bytes32 leaf = encodeLeaf(recipient, tokenIds);
    require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(tokenIds[i] <= maxClaimable, "Id out of range");
      _claimed[tokenIds[i]] = true;
      everdragons2Genesis.mint(recipient, tokenIds[i]);
    }
  }

  function maxTokenId() public view returns (uint256) {
    return maxForSale + maxClaimable - (getChainId() == 137 ? 100 : 50);
  }

  function buyTokens(uint256 quantity) external payable {
    require(msg.value >= price.mul(quantity), "Insufficient payment");
    require(nextTokenId + quantity - 1 <= maxTokenId(), "Not enough tokens left");
    uint256 nextId = nextTokenId;
    for (uint256 i = 0; i < quantity; i++) {
      everdragons2Genesis.mint(_msgSender(), nextId++);
    }
    require(nextId <= maxTokenId() + 1, "Id out of range");
    nextTokenId = nextId;
    proceedsBalance += msg.value;
  }

  function deliverCrossChainPurchase(
    uint16 nonce,
    address buyer,
    uint256 quantity
  ) external {
    require(!usedNonces[nonce], "Nonce already used");
    require(operator != address(0) && _msgSender() == operator, "Sender not the operator");
    require(nextTokenId + quantity - 1 <= maxTokenId(), "Not enough tokens left");
    uint256 nextId = nextTokenId;
    for (uint256 i = 0; i < quantity; i++) {
      everdragons2Genesis.mint(buyer, nextId++);
    }
    require(nextId <= maxTokenId() + 1, "Id out of range");
    nextTokenId = nextId;
    usedNonces[nonce] = true;
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

  function getChainId() public view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }
}
