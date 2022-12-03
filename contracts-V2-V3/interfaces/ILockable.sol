// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface ILockable {
  event LockerSet(address locker);
  event LockerRemoved(address locker);
  event ForcefullyUnlocked(uint256 tokenId);
  event Locked(uint256 tokendId);
  event Unlocked(uint256 tokendId);

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
