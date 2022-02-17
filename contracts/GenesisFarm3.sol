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
  address public operator;

  uint256 public maxClaimable;
  uint256 private _lastUnclaimed;
  mapping(uint256 => bool) private _claimed;
  bool public claimingEnded;

  constructor(
    IEverdragons2GenesisExtended everdragons2_,
    uint256 maxForSale_,
    uint256 maxClaimable_,
    address operator_
  ) {
    everdragons2Genesis = everdragons2_;
    require(everdragons2Genesis.mintEnded() == false, "Not an E2 token");
    uint256 temporaryTotalSupply = everdragons2Genesis.totalSupply();
    maxForSale = maxForSale_;
    maxClaimable = maxClaimable_;
    nextTokenId = maxClaimable + temporaryTotalSupply + 1;
    setOperator(operator_);
  }

  function setOperator(address operator_) public onlyOwner {
    require(operator_ != address(0), "operator cannot be 0x0");
    operator = operator_;
    emit OperatorSet(operator);
  }

  function price(uint256 lastId) public pure returns (uint256) {
    if (lastId < 601) {
      return 100 * 1e18;
    } else {
      return ((lastId - 401) / 100) * 100 * 1e18;
    }
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

  function endClaiming() external onlyOwner {
    claimingEnded = true;
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
  ) external {
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

  function buyTokens(uint256 quantity) external payable {
    uint256 lastId = nextTokenId + quantity - 1;
    require(msg.value >= price(lastId).mul(quantity), "Insufficient payment");
    require(nextTokenId + quantity - 1 <= maxForSale + maxClaimable, "Not enough tokens left");
    uint256 nextId = nextTokenId;
    for (uint256 i = 0; i < quantity; i++) {
      everdragons2Genesis.mint(_msgSender(), nextId++);
    }
    require(nextId <= maxForSale + maxClaimable + 1, "Id out of range");
    nextTokenId = nextId;
    proceedsBalance += msg.value;
  }

  function deliverCrossChainPurchase(address buyer, uint256 quantity) external {
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
