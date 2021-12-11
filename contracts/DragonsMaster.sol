// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEverDragons2.sol";

import "hardhat/console.sol";

contract DragonsMaster is Ownable {
  using ECDSA for bytes32;
  using SafeMath for uint256;

  event TeamAddressUpdated(address oldAddr, address newAddr);
  event SaleSet();

  struct Team {
    bytes3 name;
    uint8 percentage;
    uint224 withdrawnAmount;
  }

  mapping(address => Team) public teams;

  // < 1 word in storage
  struct Conf {
    address validator; //
    // with block numbers it would have been safer
    // but in our case the risk of fraud is very low
    uint32 startingTimestamp;
    uint16 nextTokenId;
    uint16 maxBuyableTokenId; // 10000 - 1706 - 21 = 8273
    uint8 maxPrice; // 180 = 1.8 ETH
    uint8 decrementPercentage; // 10%
    uint8 minutesBetweenDecrements; // 60 << 1 hour
    uint8 numberOfSteps; // 32 << price reduces 10% every hour
  }

  Conf public conf;
  IEverDragons2 public everDragons2;

  uint256 public proceedsBalance;
  uint256 public limit;

  mapping(address => bool) public bridges;

  modifier saleActive() {
    require(block.timestamp >= uint256(conf.startingTimestamp), "Sale not started yet");
    require(!saleEnded(), "Sale is ended or closed");
    _;
  }

  constructor(address everDragons2_) {
    everDragons2 = IEverDragons2(everDragons2_);
  }

  function updateTeamAddress(address addr) external {
    Team memory team0 = teams[_msgSender()];
    require(team0.percentage > 0, "Forbidden");
    require(addr != address(0), "No 0x0 allowed");
    teams[addr] = Team(team0.name, team0.percentage, 0);
    delete teams[_msgSender()];
    emit TeamAddressUpdated(_msgSender(), addr);
  }

  function closeSale() external onlyOwner {
    // This is irreversible.
    // We use numberOfSteps to not use a boolean that would require more gas
    conf.numberOfSteps = 0;
  }

  function init(
    Conf memory conf_,
    address[] memory bridges_,
    address edo,
    address ed2,
    address ndl
  ) external onlyOwner {
    require(conf.validator == address(0), "Sale already set");
    conf = conf_;
    teams[edo] = Team(0x65646f, 20, 0);
    teams[ed2] = Team(0x656432, 20, 0);
    teams[ndl] = Team(0x6e646c, 60, 0);
    for (uint256 i = 0; i < bridges_.length; i++) {
      bridges[bridges_[i]] = true;
    }
  }

  function currentStep(uint8 skippedSteps) public view saleActive returns (uint8) {
    uint8 step = uint8(
      block.timestamp.sub(conf.startingTimestamp).div(uint256(conf.minutesBetweenDecrements) * 60).add(skippedSteps)
    );
    if (step > conf.numberOfSteps - 1) {
      step = conf.numberOfSteps - 1;
    }
    return step;
  }

  function currentPrice(uint8 currentStep_) public view returns (uint256) {
    uint256 price = uint256(conf.maxPrice);
    for (uint8 i = 0; i < currentStep_; i++) {
      price = price.div(10).mul(9);
    }
    return price.mul(10**18).div(100);
  }

  function saleEnded() public view returns (bool) {
    return conf.numberOfSteps == 0 || conf.nextTokenId > conf.maxBuyableTokenId;
  }

  // actions

  function claimTokens(
    uint256[] memory tokenIds,
    uint8 chainId,
    bytes memory signature
  ) external saleActive {
    require(!bridges[_msgSender()], "Bridges can not claim tokens");
    require(isSignedByValidator(encodeForSignature(_msgSender(), tokenIds, chainId, 0), signature), "Invalid signature");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (chainId == 1) {
        // ETH
        require(tokenIds[i] <= 972, "Id out of range");
        tokenIds[i] += conf.maxBuyableTokenId;
      } else if (chainId == 2) {
        // Tron
        require(tokenIds[i] <= 392, "Id out of range");
        tokenIds[i] += conf.maxBuyableTokenId + 972;
      } else if (chainId == 3) {
        // POA
        require(tokenIds[i] <= 342, "Id out of range");
        tokenIds[i] += conf.maxBuyableTokenId + 972 + 392;
      } else {
        revert("Chain not supported");
      }
    }
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function giveAwayTokens(address[] memory recipients, uint256[] memory tokenIds) external onlyOwner {
    require(recipients.length == tokenIds.length, "Inconsistent lengths");
    uint16 allReserved = 972 + 392 + 342;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(
        (saleEnded() && tokenIds[i] > conf.maxBuyableTokenId) ||
          (!saleEnded() && tokenIds[i] > conf.maxBuyableTokenId + allReserved),
        "Id out of range"
      );
    }
    everDragons2.mint(recipients, tokenIds);
  }

  function buyTokens(uint256[] memory tokenIds) external payable saleActive {
    require(conf.nextTokenId + tokenIds.length - 1 <= conf.maxBuyableTokenId, "Not enough tokens left");
    uint256 price = currentPrice(currentStep(0));
    require(msg.value >= price.mul(tokenIds.length), "Insufficient payment");
    uint256 nextTokenId = uint256(conf.nextTokenId);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      // override the value with next tokenId
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    proceedsBalance += msg.value;
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function buyDiscountedTokens(
    uint256[] memory tokenIds,
    uint8 skippedSteps,
    bytes memory signature
  ) external payable saleActive {
    require(conf.nextTokenId + tokenIds.length - 1 <= conf.maxBuyableTokenId, "Not enough tokens left");
    require(isSignedByValidator(encodeForSignature(_msgSender(), tokenIds, 1, skippedSteps), signature), "Invalid signature");
    uint256 price = currentPrice(currentStep(skippedSteps));
    require(msg.value >= price.mul(tokenIds.length), "Insufficient payment");
    uint256 nextTokenId = uint256(conf.nextTokenId);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      // override the value with next tokenId
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    proceedsBalance += msg.value;
    everDragons2.mint(_msgSender(), tokenIds);
  }

  // cryptography

  function isSignedByValidator(bytes32 _hash, bytes memory _signature) public view returns (bool) {
    return conf.validator == ECDSA.recover(_hash, _signature);
  }

  function encodeForSignature(
    address addr,
    uint256[] memory tokenIds,
    uint8 chainId,
    uint8 skippedSteps
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x00", // EIP-191
          addr,
          tokenIds,
          chainId,
          skippedSteps
        )
      );
  }

  // withdraw

  function claimEarnings(uint256 amount) external {
    uint256 available = withdrawable(_msgSender());
    require(amount <= available, "Insufficient funds");
    teams[_msgSender()].withdrawnAmount += uint224(amount);
    (bool success, ) = _msgSender().call{value: amount}("");
    require(success);
  }

  function withdrawable(address addr) public view returns (uint256) {
    if (teams[addr].percentage > 0) {
      return proceedsBalance.div(100).mul(teams[addr].percentage).sub(teams[addr].withdrawnAmount);
    } else {
      return 0;
    }
  }
}
