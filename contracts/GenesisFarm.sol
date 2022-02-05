// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

// Author: Francesco Sullo <francesco@sullo.co>
// Everdragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEverdragons2Genesis.sol";
import "./IManager.sol";

import "hardhat/console.sol";

contract GenesisFarm is Ownable, IManager {
  using SafeMath for uint256;

  uint256 private _nextTokenId = 1;
  uint256 public maxForSale;
  uint256 public proceedsBalance;
  uint256 public price;
  uint256 public saleStartAt;

  mapping(address => uint8) public got;

  IEverdragons2Genesis public everdragons2Genesis;

  constructor(
    address everdragons2_,
    uint256 maxForSale_,
    uint16 price_,
    uint saleStartAt_
  ) {
    everdragons2Genesis = IEverdragons2Genesis(everdragons2_);
    require(everdragons2Genesis.mintEnded() == false, "Not an E2 token");
    require(saleStartAt_ > block.timestamp, "Invalid sale start time");
    maxForSale = maxForSale_;
    price = uint256(price_).mul(10**18);
    saleStartAt = saleStartAt_;
  }

  function isManager() external pure override returns (bool) {
    return true;
  }

  function giveAway350Tokens(address[] memory recipients, uint256[] memory quantities) external onlyOwner {
    require(_nextTokenId >= maxForSale, "Sale not ended yet");
    require(recipients.length == quantities.length, "Inconsistent lengths");
    uint256 nextId = _nextTokenId;
    for (uint256 i = 0; i < recipients.length; i++) {
      if (got[recipients[i]] == 0) {
        for (uint256 j = 0; j < quantities[i]; j++) {
          everdragons2Genesis.mint(recipients[i], nextId++);
        }
        // to avoid giving someone tokens more times by mistake
        got[recipients[i]] = uint8(quantities[i]);
      }
    }
    _nextTokenId = nextId;
  }

  function buyTokens(uint256 quantity) external payable {
    require(block.timestamp >= saleStartAt, "Sale not started yet");
    require(_nextTokenId + quantity - 1 <= maxForSale, "Not enough tokens left");
    require(msg.value >= price.mul(quantity), "Insufficient payment");
    uint256 nextId = _nextTokenId;
    for (uint256 i = 0; i < quantity; i++) {
      everdragons2Genesis.mint(_msgSender(), nextId++);
    }
    _nextTokenId = nextId;
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

  function updateMaxForSale(uint maxForSale_) external onlyOwner {
    require(maxForSale_ != maxForSale, "Not a change");
    maxForSale = maxForSale_;
  }


}
