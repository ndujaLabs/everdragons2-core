// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// Author: Francesco Sullo <francesco@sullo.co>
// EverDragons2 website: https://everdragons2.com

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEverDragons2.sol";

import "hardhat/console.sol";

contract DragonsFarm is Ownable {
  using ECDSA for bytes32;
  using SafeMath for uint256;


  event TeamAddressUpdated(address oldAddr, address newAddr);
  event DropSet();
  event WalletWhitelistedForDiscount(address wallet, uint8 skippedSteps);
  event WinnerWalletWhitelisted(address wallet, uint8 totalWon);

  bool private _mintEnded;
  uint8 public constant EDO = 1;
  uint8 public constant ED2 = 2;
  uint8 public constant DAO = 3;
  uint8 public constant NDL = 4;

  struct Team {
    uint8 id;
    uint8 percentage;
    uint224 withdrawnAmount;
  }

  mapping(address => Team) public teams;
  mapping(uint8 => address) public teamAddressById;

  // < 1 word in storage
  struct Conf {
    // 1st word
    address validator; //
    // with block numbers it would have been safer
    // but in our case the risk of fraud is very low
    uint32 startingTimestamp;
    uint16 nextTokenId;
    uint16 maxTokenIdForSale; // 7900
    uint32 maxPrice; // from 6000 * 100 to 190.35 * 100 in 32 steps
    // 2nd word
    uint8 decrementPercentage; // 10%
    uint8 minutesBetweenDecrements; // 10 --
    uint8 numberOfSteps; // 32 << price reduces 10% every time
    uint16 edOnEthereum; // 972
    uint16 edOnPoa; // 342
    uint16 edOnTron; // 392
    uint8 maxTokenPerWhitelistedWallet; // 3
//    uint16 nextWonTokenId;
  }

  Conf public conf;
  IEverDragons2 public everDragons2;
  uint private _nextWonTokenId;

  uint256 public proceedsBalance;
  uint256 public limit;
  mapping(address => uint8) public giveawaysWinners;
  mapping(address => uint8) public levelOfWhitelistedWallet;
  mapping(address => bool) public whitelisted;
  mapping(address => uint8) public tokenGetByWhitelistedWallet;

  modifier saleActive() {
    require(block.timestamp >= uint256(conf.startingTimestamp), "Sale not started yet");
    require(!saleEnded(), "Sale is ended or closed");
    _;
  }

  constructor(address everDragons2_) {
    everDragons2 = IEverDragons2(everDragons2_);
  }


  function endMinting() external onlyOwner {
    _mintEnded = true;
  }

  function mintingIsEnded() external view returns(bool) {
    return _mintEnded;
  }

  function updateTeamAddress(address addr) external {
    require(addr != address(0), "No 0x0 allowed");
    require(teams[addr].percentage == 0, "Address already used");
    Team memory team0 = teams[_msgSender()];
    require(team0.percentage > 0, "Forbidden");
    teams[addr] = Team(team0.id, team0.percentage, team0.withdrawnAmount);
    teamAddressById[team0.id] = addr;
    delete teams[_msgSender()];
    emit TeamAddressUpdated(_msgSender(), addr);
  }

  function closeSale() external onlyOwner {
    // This is irreversible.
    // We use numberOfSteps to not use a boolean that would require more gas
    conf.numberOfSteps = 0;
  }

  mapping(address => bool) private _tmp;

  function init(
    Conf memory conf_,
    address edo,
    address ed2,
    address dao,
    address ndl
  ) external onlyOwner {
    require(conf.validator == address(0), "Sale already set");
    _nextWonTokenId = conf_.maxTokenIdForSale + conf_.edOnEthereum + conf_.edOnPoa + conf_.edOnTron + 1;
    conf = conf_;
    require(edo != address(0) && ed2 != address(0) && dao != address(0) && ndl != address(0), "Address null not allowed");
    _tmp[edo] = true;
    teams[edo] = Team(EDO, 20, 0);
    teamAddressById[EDO] = edo;
    require(!_tmp[ed2], "Address repeated");
    _tmp[ed2] = true;
    teams[ed2] = Team(ED2, 20, 0);
    teamAddressById[ED2] = ed2;
    require(!_tmp[dao], "Address repeated");
    _tmp[dao] = true;
    teams[dao] = Team(DAO, 20, 0);
    teamAddressById[DAO] = dao;
    require(!_tmp[ndl], "Address repeated");
    teams[ndl] = Team(NDL, 40, 0);
    teamAddressById[NDL] = ndl;
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
    return conf.numberOfSteps == 0 || conf.nextTokenId > conf.maxTokenIdForSale;
  }

  // actions

  function claimTokens(
    uint256[] memory tokenIds,
    uint8 otherChainId,
    bytes memory signature
  ) external saleActive {
    require(!_mintEnded, "Mint ended");
    require(
      isSignedByValidator(encodeForSignature(_msgSender(), tokenIds, otherChainId, getChainId()), signature),
      "Invalid signature"
    );
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (otherChainId == 1) {
        // ETH
        require(tokenIds[i] <= conf.edOnEthereum, "Id out of range");
        tokenIds[i] += conf.maxTokenIdForSale;
      } else if (otherChainId == 2) {
        // POA
        require(tokenIds[i] <= conf.edOnPoa, "Id out of range");
        tokenIds[i] += conf.maxTokenIdForSale + conf.edOnEthereum;
      } else if (otherChainId == 3) {
        // TRON
        require(tokenIds[i] <= conf.edOnTron, "Id out of range");
        tokenIds[i] += conf.maxTokenIdForSale + conf.edOnEthereum + conf.edOnPoa;
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
      require(tokenIds[i] < everDragons2.lastTokenId(), "Id out of range");
      require(
        saleEnded() ||
          (tokenIds[i] > conf.maxTokenIdForSale + allReserved &&
            tokenIds[i] < everDragons2.lastTokenId() - everDragons2.teamWallets().length),
        "Id out of range"
      );
    }
    // it will revert if any token has already been minted
    everDragons2.mint(recipients, tokenIds);
  }

  function claimWonTokens() external {
    require(!_mintEnded, "Mint ended");
    require(giveawaysWinners[_msgSender()] > 0, "Not a winner");
    uint256 quantity = uint256(giveawaysWinners[_msgSender()]) - 1;
    require(quantity > 0, "Tokens already minted");
    uint256 nextTokenId = _nextWonTokenId;
    uint256[] memory tokenIds = new uint256[](quantity);
    uint cap = uint(everDragons2.lastTokenId() - everDragons2.teamWallets().length);
    for (uint256 i = 0; i < quantity; i++) {
      require(nextTokenId < cap, "Id out of range");
      tokenIds[i] = nextTokenId++;
    }
    _nextWonTokenId = nextTokenId;
    // it will remain different than zero so that we avoid
    // adding to the whitelist again after the first mint
    giveawaysWinners[_msgSender()] = 1;
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function buyTokens(uint256 quantity) external payable saleActive {
    require(!_mintEnded, "Mint ended");
    require(conf.nextTokenId + quantity - 1 <= conf.maxTokenIdForSale, "Not enough tokens left");
    uint256 price = currentPrice(currentStep(0));
    require(msg.value >= price.mul(quantity), "Insufficient payment");
    uint256 nextTokenId = uint256(conf.nextTokenId);
    uint256[] memory tokenIds = new uint256[](quantity);
    for (uint256 i = 0; i < quantity; i++) {
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    proceedsBalance += msg.value;
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function buyDiscountedTokens(uint256 quantity) external payable saleActive {
    require(!_mintEnded, "Mint ended");
    require(conf.nextTokenId + quantity - 1 <= conf.maxTokenIdForSale, "Not enough tokens left");
    require(levelOfWhitelistedWallet[_msgSender()] > 0, "Not whitelisted");
    require(
      tokenGetByWhitelistedWallet[_msgSender()] + quantity <= conf.maxTokenPerWhitelistedWallet,
      "You are trying to get too many tokens"
    );
    uint256 price = currentPrice(currentStep(levelOfWhitelistedWallet[_msgSender()]));
    require(msg.value >= price.mul(quantity), "Insufficient payment");
    uint256 nextTokenId = uint256(conf.nextTokenId);
    uint256[] memory tokenIds = new uint256[](quantity);
    for (uint256 i = 0; i < quantity; i++) {
      tokenIds[i] = nextTokenId++;
    }
    conf.nextTokenId = uint16(nextTokenId);
    proceedsBalance += msg.value;
    tokenGetByWhitelistedWallet[_msgSender()] += uint8(quantity);
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function addWalletsToWhitelists(address[] memory wallets, uint8 numberOfStepsSkipped) external onlyOwner {
    for (uint256 i = 0; i < wallets.length; i++) {
      require(wallets[i] != address(0), "Null address");
      require(!whitelisted[wallets[i]], "Already whitelisted");
      whitelisted[wallets[i]] = true;
      levelOfWhitelistedWallet[wallets[i]] = numberOfStepsSkipped;
      emit WalletWhitelistedForDiscount(wallets[i], numberOfStepsSkipped);
    }
  }

  function addWinnerWalletsToWhitelists(address[] memory wallets, uint8[] memory numberOfTokenWon) external onlyOwner {
    require(wallets.length == numberOfTokenWon.length, "Inconsistent arrays");
    for (uint256 i = 0; i < wallets.length; i++) {
      require(wallets[i] != address(0), "Null address");

      if (giveawaysWinners[wallets[i]] > 0) {
        // wallet whitelisted again by mistake. Let's not revert :-)
        continue;
      } else {
        giveawaysWinners[wallets[i]] = numberOfTokenWon[i] + 1;
        emit WinnerWalletWhitelisted(wallets[i], numberOfTokenWon[i]);
      }
    }
  }

  function mintUnmintedTokens(uint startFrom) external onlyOwner {
    require(_mintEnded, "Mint not ended");
    uint initialGas = gasleft();
    // we assume that the start is the first not minted token
    everDragons2.mint(owner(), startFrom);
    uint requiredGas = initialGas - gasleft();
    for (uint i = startFrom + 1; i< everDragons2.lastTokenId(); i++) {
      if (gasleft() < requiredGas + 10000) {
        return;
      }
      if (!everDragons2.isMinted(i)) {
        everDragons2.mint(owner(), i);
      }
    }
  }

  // cryptography

  function isSignedByValidator(bytes32 _hash, bytes memory _signature) public view returns (bool) {
    return conf.validator == ECDSA.recover(_hash, _signature);
  }

  function getChainId() public view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }

  function encodeForSignature(
    address addr,
    uint256[] memory tokenIds,
    uint8 otherChainId,
    uint256 chainId
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          addr,
          tokenIds,
          otherChainId,
          chainId
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
