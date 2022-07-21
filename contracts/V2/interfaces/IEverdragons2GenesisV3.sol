// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface IEverdragons2GenesisV3 {
  event LockerSet(address locker);
  event LockerRemoved(address locker);
  event LockRemoved(uint256 tokenId);
  event Locked(uint256 tokendId);
  event Unlocked(uint256 tokendId);

  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  function contractURI() external view returns (string memory);

  function isLocked(uint256 tokenID) external view returns (bool);

  function lockerOf(uint256 tokenID) external view returns (address);

  function isLocker(address _locker) external view returns (bool);

  function setLocker(address pool) external;

  function removeLocker(address pool) external;

  function hasLocks(address owner) external view returns (bool);

  function lock(uint256 tokenID) external;

  function unlock(uint256 tokenID) external;

  function unlockIfRemovedLocker(uint256 tokenID) external;
}
