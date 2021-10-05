// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEverDragonsERC721Token.sol";
//import "hardhat/console.sol";

interface IEverDragons2 {

  function mint(address recipient, uint256[] memory tokenIds) external;

  function mint(address[] memory recipients, uint256[] memory tokenIds) external;

  function ownerOf(uint256 tokenId) external view returns (address);
}


contract DragonsMaster is Ownable {
  using ECDSA for bytes32;
  using SafeMath for uint256;

  event TeamAddressUpdated(address oldAddr, address newAddr);
  event SaleSet();

  IEverDragonsERC721Token public everDragons;
  IEverDragons2 public everDragons2;

  uint256 public ethBalance;
  uint256 public limit;

  address internal _bridge1;
  address internal _bridge2;

  struct Team {
    bytes3 name;
    uint8 percentage;
    uint224 withdrawnAmount;
  }

  mapping(address => Team) public teams;
  mapping(address => bool) public discounted;

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

  modifier saleActive() {
    require(block.timestamp >= uint(conf.startingTimestamp), "Sale not started yet");
    require(!saleEnded(), "Sale is ended or closed");
    _;
  }

  modifier isNotABridge() {
    require(_msgSender() != _bridge1 && _msgSender() != _bridge2, "Bridge cannot claim tokens");
    _;
  }

  modifier enoughTokensLeft(uint tokenIdsLength) {
    require(conf.nextTokenId + tokenIdsLength - 1 <= conf.maxBuyableTokenId, "Not enough tokens left");
    _;
  }

  constructor(address addr, address addr2) {
    everDragons2 = IEverDragons2(addr);
    // 0x3B6aad76254A79A9E256C8AeD9187DEa505AAD52
    everDragons = IEverDragonsERC721Token(addr2);
    // 0x772Da237fc93ded712E5823b497Db5991CC6951e);
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
    address edo,
    address ed2,
    address ndl,
    address bridge1, // 0xeE0f42712598f28521f45237cf42ad95F1d52DAa
    address bridge2  // 0x74AF9991d5FEa09EBB042CaFE51972D89aCDaFC8
  ) external onlyOwner {
    require(conf.validator == address(0), "Sale already set");
    conf = conf_;
    teams[edo] = Team(0x65646f, 20, 0);
    teams[ed2] = Team(0x656432, 20, 0);
    teams[ndl] = Team(0x6e646c, 60, 0);
    _bridge1 = bridge1;
    _bridge2 = bridge2;
  }

  function currentStep(uint8 skippedSteps) public view saleActive returns (uint8) {
    uint8 step = uint8(block.timestamp.sub(conf.startingTimestamp).div(uint(conf.minutesBetweenDecrements) * 60).add(skippedSteps));
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
    return price.mul(10 ** 18).div(100);
  }

  function saleEnded() public view returns (bool) {
    return conf.numberOfSteps == 0 || conf.nextTokenId > conf.maxBuyableTokenId;
  }

  // actions

  function claimTokens(uint[] memory tokenIds) external isNotABridge saleActive {
    for (uint i = 0; i < tokenIds.length; i++) {
      require(everDragons.ownerOf(tokenIds[i]) == _msgSender(), "Not the token holder");
      tokenIds[i] = tokenIds[i].add(conf.maxBuyableTokenId);
    }
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function giveAwayTokens(address[] memory recipients, uint256[] memory tokenIds) external onlyOwner {
    require(recipients.length == tokenIds.length, "Inconsistent lengths");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(
        (saleEnded() && tokenIds[i] > conf.maxBuyableTokenId) ||
        (!saleEnded() && tokenIds[i] > conf.maxBuyableTokenId + 972),
        "Id out of range"
      );
    }
    everDragons2.mint(recipients, tokenIds);
  }

  function buyTokens(uint tokens) external saleActive enoughTokensLeft(tokens) payable {
    uint256 price = currentPrice(currentStep(0));
    require(msg.value >= price.mul(tokens), "Insufficient payment");
    uint[] memory tokenIds = new uint[](tokens);
    uint nextTokenId = uint(conf.nextTokenId);
    for (uint256 i = 0; i < tokens; i++) {
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    ethBalance += msg.value;
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function buyDiscountedTokens(
    uint256 tokens,
    uint8 skippedSteps,
    bytes memory signature
  ) external saleActive enoughTokensLeft(tokens) payable {
    require(
      isSignedByValidator(encodeForSignature(_msgSender(), tokens, skippedSteps), signature),
      "Invalid signature"
    );
    require(discounted[_msgSender()] == false, "Discount already used");
    uint256 price = currentPrice(currentStep(skippedSteps));
    require(msg.value >= price.mul(tokens), "Insufficient payment");
    uint[] memory tokenIds = new uint[](tokens);
    uint nextTokenId = uint(conf.nextTokenId);
    for (uint256 i = 0; i < tokens; i++) {
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    ethBalance += msg.value;
    everDragons2.mint(_msgSender(), tokenIds);
    discounted[_msgSender()] = true;
  }

  // cryptography

  function isSignedByValidator(bytes32 _hash, bytes memory _signature) public view returns (bool) {
    return conf.validator == ECDSA.recover(_hash, _signature);
  }

  function encodeForSignature(
    address addr,
    uint256 tokens,
    uint8 skippedSteps
  ) public pure returns (bytes32) {
    return
    keccak256(
      abi.encodePacked(
        "\x19\x00", // EIP-191
        addr,
        tokens,
        skippedSteps
      )
    );
  }

  // withdraw

  function claimEarnings(uint256 amount) external {
    require(saleEnded(), "Sale still active");
    uint256 available = withdrawable(_msgSender());
    require(amount <= available, "Insufficient funds");
    teams[_msgSender()].withdrawnAmount += uint224(amount);
    (bool success,) = _msgSender().call{value : amount}("");
    require(success);
  }

  function withdrawable(address addr) public view returns (uint256) {
    if (teams[addr].percentage > 0) {
      return ethBalance.div(100).mul(teams[addr].percentage).sub(teams[addr].withdrawnAmount);
    } else {
      return 0;
    }
  }
}
