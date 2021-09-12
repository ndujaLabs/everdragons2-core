// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IEverDragons2.sol";

contract EverDragons2Manager is Ownable {
  using ECDSA for bytes32;
  using SafeMath for uint256;

  event TeamPointsSet();
  event SaleSet();

  struct Point {
    address teamMember;
    uint16 points;
  }

  Point[] public teamPoints;
  mapping(address => uint256) public withdrawnAmounts;

  struct Conf {
    uint16 eVOnEth; // 972
    uint16 eVOnTron; // 392
    uint16 eVOnPOA; // 342
    uint16 price; // 0.1 ETH
    uint16 presaleDiscount; // 20%
    uint16 maxTokenId; // 8000
    uint16 maxPresaleTokenId; // 800
    uint16 durationPresale; // in number of blocks
    uint8 maxPerWalletInPresale; // 1
    uint8 maxPerWalletInSale; // 5
    uint8 ethId; // 1
    uint8 tronId; // 2
    uint8 poaId; // 3
  }

  uint256 public nextTokenId = 1;
  uint256 public ethBalance;
  uint256 public startingBlock;

  Conf public conf;
  IEverDragons2 public everDragons2;

  address public validator;
  bool public saleClosed;
  bool public initiated;
  bool public presaleClosed;

  mapping(bytes16 => bool) private _signatureUsed;
  mapping(address => bool) public bridge;

  constructor(address everDragons2_) {
    everDragons2 = IEverDragons2(everDragons2_);
  }

  function setTeamPoints(address[] memory addrs, uint16[] memory points) external onlyOwner {
    require(startingBlock > block.number, "Sale has already started");
    if (teamPoints.length != 0) {
      // fixing a previous mistake
      delete teamPoints;
    }
    uint256 total = 0;
    for (uint256 i = 0; i < addrs.length; i++) {
      total += points[i];
    }
    // 10 is 0.1%, 10000 is 100%
    require(total == 10000, "All team points must sum to 10000");
    for (uint256 i = 0; i < addrs.length; i++) {
      teamPoints.push(Point(addrs[i], points[i]));
    }
    emit TeamPointsSet();
  }

  function closeSale() external onlyOwner {
    // this is irreversible
    saleClosed = true;
  }

  function init(
    address validator_,
    Conf memory conf_,
    uint256 startingBlock_,
    address[] memory bridges
  ) external onlyOwner {
    require(initiated == false, "Sale already set");
    validator = validator_;
    // right now:
    //    conf_.eVOnPOA = 342;
    //    conf_.eVOnTron = 392;
    //    conf_.eVOnEth = 972;
    conf = conf_;
    startingBlock = startingBlock_;
    for (uint256 i = 0; i < bridges.length; i++) {
      bridge[bridges[i]] = true;
    }
    initiated = true;
  }

  function saleEnded() public view returns (bool) {
    return saleClosed || nextTokenId > conf.maxTokenId;
  }

  function presaleEnded() public view returns (bool) {
    return presaleClosed || nextTokenId > conf.maxPresaleTokenId;
  }

  function claimToken(
    uint256[] memory tokenIds,
    uint8 chainId,
    bytes memory signature
  ) external {
    require(!saleEnded(), "Sale is ended or closed");
    require(!bridge[_msgSender()], "Bridges can not claim tokens");
    require(isSignedByValidator(encodeForSignature(_msgSender(), tokenIds, uint256(chainId)), signature), "Invalid signature");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (chainId == conf.ethId) {
        require(tokenIds[i] <= conf.eVOnEth, "Id out of range");
        tokenIds[i] += conf.maxTokenId;
      } else if (chainId == conf.tronId) {
        require(tokenIds[i] <= conf.eVOnTron, "Id out of range");
        tokenIds[i] += conf.maxTokenId + conf.eVOnEth;
      } else if (chainId == conf.poaId) {
        require(tokenIds[i] <= conf.eVOnPOA, "Id out of range");
        tokenIds[i] += conf.maxTokenId + conf.eVOnEth + conf.eVOnTron;
      } else {
        revert("Chain not supported");
      }
    }
    everDragons2.mint(_msgSender(), tokenIds);
  }

  function giveAwayTokens(address[] memory recipients, uint256[] memory tokenIds) external onlyOwner {
    require(recipients.length == tokenIds.length, "Inconsistent lengths");
    uint16 allReserved = conf.eVOnEth + conf.eVOnTron + conf.eVOnPOA;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(
        (saleEnded() && tokenIds[i] > conf.maxTokenId) || (!saleEnded() && tokenIds[i] > conf.maxTokenId + allReserved),
        "Id out of range"
      );
    }
    everDragons2.mint(recipients, tokenIds);
  }

  function sale(
    uint256[] memory tokenIds,
    uint256 timestamp,
    bytes memory signature
  ) external payable {
    require(block.number >= startingBlock, "Sale not started yet");
    require(!saleEnded(), "Sale is ended or closed");
    if (block.number > startingBlock.add(conf.durationPresale)) {
      require(tokenIds.length <= conf.maxPerWalletInSale, "Too many tokens required");
      require(nextTokenId + tokenIds.length - 1 <= conf.maxTokenId, "Not enough tokens left");
      require(msg.value >= uint256(conf.price).mul(tokenIds.length), "Insufficient payment");
    } else {
      require(tokenIds.length <= conf.maxPerWalletInPresale, "Too many tokens required");
      require(nextTokenId + tokenIds.length - 1 <= conf.maxPresaleTokenId, "Not enough tokens left");
      require(
        msg.value >= uint256(conf.price).mul(tokenIds.length).mul(100 - conf.presaleDiscount).div(100),
        "Insufficient payment"
      );
    }
    require(isSignedByValidator(encodeForSignature(_msgSender(), tokenIds, timestamp), signature), "Invalid signature");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      tokenIds[i] = nextTokenId++;
    }
    ethBalance += msg.value;
    everDragons2.mint(_msgSender(), tokenIds);
    // last requirement, to let fraudster to pay all the gas for nothing
    bytes16 sig = bytes16(keccak256(signature));
    require(!_signatureUsed[sig], "Signature already used");
    _signatureUsed[sig] = true;
  }

  function isSignedByValidator(bytes32 _hash, bytes memory _signature) public view returns (bool) {
    return validator == ECDSA.recover(_hash, _signature);
  }

  function _teamMemberEarnings(uint16 points) internal view returns (uint256) {
    return ethBalance.div(10000).mul(points);
  }

  function claimEarnings(uint256 amount) external {
    require(saleClosed || nextTokenId > conf.maxTokenId, "Sale is still active");
    uint256 available = amountAvailableForWithdrawn(_msgSender());
    require(amount <= available, "Insufficient funds");
    _withdrawEarnings(amount);
  }

  function _withdrawEarnings(uint256 amount) internal {
    withdrawnAmounts[_msgSender()].add(amount);
    (bool success, ) = _msgSender().call{value: amount}("");
    require(success);
  }

  function amountAvailableForWithdrawn(address teamMember) public view returns (uint256) {
    if (saleClosed || nextTokenId > conf.maxTokenId) {
      for (uint256 i = 0; i < teamPoints.length; i++) {
        if (teamPoints[i].teamMember == teamMember) {
          return ethBalance.div(10000).mul(teamPoints[i].points).sub(withdrawnAmounts[teamMember]);
        }
      }
    }
    return 0;
  }

  function encodeForSignature(
    address addr,
    uint256[] memory tokenIds,
    uint256 chainIdOrTimestamp
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x00", // EIP-191
          addr,
          tokenIds,
          chainIdOrTimestamp
        )
      );
  }
}
