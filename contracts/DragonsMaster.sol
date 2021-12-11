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
  event DropSet();
  event WalletWhitelistedForDiscount(address wallet);

  uint8 public constant EDO = 1;
  uint8 public constant ED2 = 2;
  uint8 public constant DAO = 3;
  uint8 public constant NDL = 4;

  struct Team {
    uint8 name;
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
    uint16 maxBuyableTokenId; // 7900
    uint8 maxPrice; // from 5000 to 191 in 32 steps
    uint8 decrementPercentage; // 10%
    uint8 minutesBetweenDecrements; // 10 --
    uint8 numberOfSteps; // 32 << price reduces 10% every time
    uint16 edOnEthereum; // 972
    uint16 edOnPoa; // 342
    uint16 edOnTron; // 392
    uint8 maxTokenPerWhitelistedWallet; // 3
  }

  Conf public conf;
  IEverDragons2 public everDragons2;

  uint256 public proceedsBalance;
  uint256 public limit;
  mapping (address => uint8) public giveawaysWinners;
  mapping (address => uint8) public levelOfWhitelistedWallet;
  mapping (address => uint8) public tokenGetByWhitelistedWallet;

  modifier saleActive() {
    require(block.timestamp >= uint256(conf.startingTimestamp), "Sale not started yet");
    require(!saleEnded(), "Sale is ended or closed");
    _;
  }

  constructor(address everDragons2_) {
    everDragons2 = IEverDragons2(everDragons2_);
  }

  function updateTeamAddress(address addr) external {
    require(addr != address(0), "No 0x0 allowed");
    require(teams[addr].percentage == 0, "Address already used");
    Team memory team0 = teams[_msgSender()];
    require(team0.percentage > 0, "Forbidden");
    teams[addr] = Team(team0.name, team0.percentage, team0.withdrawnAmount);
    delete teams[_msgSender()];
    emit TeamAddressUpdated(_msgSender(), addr);
  }

  function closeSale() external onlyOwner {
    // This is irreversible.
    // We use numberOfSteps to not use a boolean that would require more gas
    conf.numberOfSteps = 0;
  }

  mapping (address => bool) private _tmp;

  function init(
    Conf memory conf_,
    address edo,
    address ed2,
    address dao,
    address ndl
  ) external onlyOwner {
    require(conf.validator == address(0), "Sale already set");
    conf = conf_;
    require(edo != address(0) && ed2 != address(0) && dao != address(0) && ndl != address(0), "Address null not allowed");
    _tmp[edo] = true;
    teams[edo] = Team(EDO, 20, 0);
    require(!_tmp[ed2], "Address repeated");
    _tmp[ed2] = true;
    teams[ed2] = Team(ED2, 20, 0);
    require(!_tmp[dao], "Address repeated");
    _tmp[dao] = true;
    teams[dao] = Team(DAO, 20, 0);
    require(!_tmp[ndl], "Address repeated");
    teams[ndl] = Team(NDL, 40, 0);
    emit DropSet();
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
    require(isSignedByValidator(encodeForSignature(_msgSender(), tokenIds, chainId, 0), signature), "Invalid signature");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (chainId == 1) {
        // ETH
        require(tokenIds[i] <= conf.edOnEthereum, "Id out of range");
        tokenIds[i] += conf.maxBuyableTokenId;
      } else if (chainId == 2) {
        // POA
        require(tokenIds[i] <= conf.edOnPoa, "Id out of range");
        tokenIds[i] += conf.maxBuyableTokenId + conf.edOnEthereum;
      } else if (chainId == 3) {
        // TRON
        require(tokenIds[i] <= conf.edOnTron, "Id out of range");
        tokenIds[i] += conf.maxBuyableTokenId + conf.edOnEthereum + conf.edOnPoa;
      } else {
        revert("Chain not supported");
      }
    }
    everDragons2.mint(_msgSender(), tokenIds);
  }


  function giveAwayTokens(address[] memory recipients, uint256[] memory tokenIds) external onlyOwner {
    require(recipients.length == tokenIds.length, "Inconsistent lengths");
    uint16 allReserved = conf.edOnPoa + conf.edOnEthereum + conf.edOnTron;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(saleEnded() || tokenIds[i] > conf.maxBuyableTokenId + allReserved,
        "Id out of range"
      );
    }
    // it will revert if any token has already been minted
    everDragons2.mint(recipients, tokenIds);
  }

  function claimWonTokens() external {
    uint quantity = uint(giveawaysWinners[_msgSender()]);
    require(quantity > 0, "Not a winner");
    uint256 nextTokenId = uint256(conf.nextTokenId);
    uint256[] memory tokenIds = new uint256[](quantity);
    for (uint256 i = 0; i < quantity; i++) {
      // override the value with next tokenId
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function buyTokens(uint256 quantity) external payable saleActive {
    require(conf.nextTokenId + quantity - 1 <= conf.maxBuyableTokenId, "Not enough tokens left");
    uint256 price = currentPrice(currentStep(0));
    require(msg.value >= price.mul(quantity), "Insufficient payment");
    uint256 nextTokenId = uint256(conf.nextTokenId);
    uint256[] memory tokenIds = new uint256[](quantity);
    for (uint256 i = 0; i < quantity; i++) {
      // override the value with next tokenId
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    proceedsBalance += msg.value;
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function buyDiscountedTokens(
    uint256 quantity
  ) external payable saleActive {
    require(conf.nextTokenId + quantity - 1 <= conf.maxBuyableTokenId, "Not enough tokens left");
    require(tokenGetByWhitelistedWallet[_msgSender()] + quantity <= conf.maxTokenPerWhitelistedWallet, "You are trying to get too many tokens");
    uint256 price = currentPrice(currentStep(levelOfWhitelistedWallet[_msgSender()]));
    require(msg.value >= price.mul(quantity), "Insufficient payment");
    uint256 nextTokenId = uint256(conf.nextTokenId);
    uint256[] memory tokenIds = new uint256[](quantity);
    for (uint256 i = 0; i < quantity; i++) {
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    proceedsBalance += msg.value;
    tokenGetByWhitelistedWallet[_msgSender()] -= uint8(quantity);
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function addWalletsToWhitelists(address[] memory wallets, uint8 numberOfStepsSkipped) external onlyOwner {
    for (uint i=0;i < wallets.length;i++) {
      if (levelOfWhitelistedWallet[wallets[i]] == 0) {
        // wallet whitelisted again by mistake. Let's not revert :-)
        continue;
      } else {
        levelOfWhitelistedWallet[wallets[i]] = numberOfStepsSkipped;
        emit WalletWhitelistedForDiscount(wallets[i]);
      }
    }
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
          "\x19\x01", // EIP-191
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
    require(amount != 0, "Unauthorized or depleted");
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
