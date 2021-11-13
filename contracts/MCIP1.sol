// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IMCIP1.sol";

contract MCIP1 is IMCIP1 {
  mapping(uint256 => Metadata) internal _metadata;
  mapping(uint8 => uint256) internal _firstMutables;
  mapping(uint8 => uint256) internal _latestAttributeIndexes;

  // for version 1 of the MCIP-1, it must be 2
  uint256 internal _maxStatusShiftPosition = 2;

  /// @notice Retrieve the index of the first mutable attribute
  /// @dev By convention, the attributes array first elements are immutable, followed
  /// by mutable attributes. To know which one are mutable, all we need is the index
  /// of the first mutable attribute
  /// @param _tokenId The id of the token for whom to query the first mutable attribute
  /// @return The index
  function firstMutable(uint256 _tokenId) public view returns (uint256) {
    return _firstMutables[_metadata[_tokenId].version];
  }

  /// @notice Returns the index of the last supported attributes
  /// @dev An NFT can have a variable number of attributes or a fixed one.
  /// It returns the index of the last accepted attribute index. For example,
  /// if an NFT has 16 immutable traits, and 5 mutable one and no other can be added,
  /// it should return 16 + 5 - 1 => 20
  /// If there is no limit, if should return 29
  /// @param _tokenId The id of the token for whom to query the first mutable attribute
  /// @return The index
  function latestAttributeIndex(uint256 _tokenId) public view returns (uint256) {
    return _latestAttributeIndexes[_metadata[_tokenId].version];
  }

  /// @notice Retrieve the mutability of an attribute based on its index
  /// @dev It returns a boolean. Mutable: true, immutable: false. It should use
  /// firstMutable to get the value
  /// @param _tokenId The id of the token
  /// @param _attributeIndex The index of the attribute for whom to query the mutability
  /// @return The mutability
  function isMutable(uint256 _tokenId, uint256 _attributeIndex) public view returns (bool) {
    return firstMutable(_tokenId) <= _attributeIndex;
  }

  function metadataOf(uint256 _tokenId) public view override returns (Metadata memory) {
    return _metadata[_tokenId];
  }

  /// @notice Sets the initial attributes of a token
  /// @dev Throws if the already set
  /// For example, an NFT can have a factory contract who manages minting and changes. In
  /// that case, only the factory contract should be allowed to execute the function.
  /// At first execution if should allow to set mutable and immutable attributes up.
  /// At further calls, it must revert if trying to change an immutable attribute.
  /// @param _tokenId The id of the token for whom to change the attributes
  /// @param _version The version. It must revert if a not supported version
  /// @param _initialStatus The initial value of the status.
  /// @param _initialAttributes The array of the initial attributes
  /// @return true if the change is successful
  function initUpdateAttributes(
    uint256 _tokenId,
    uint8 _version,
    uint8 _initialStatus,
    uint8[30] memory _initialAttributes
  ) public returns (bool) {
    require(_firstMutables[_version] != 0, "version not supported");
    _metadata[_tokenId] = Metadata(_version, _initialStatus, _initialAttributes);
    return true;
  }

  /// @notice Sets the attributes of a token after first set up
  /// @dev Throws if the sender is not an operator authorized in the contract.
  /// @param _tokenId The id of the token for whom to change the attributes
  /// @param _index The index of the attribute to be changed
  /// @param _value The value of the attribute to be changed
  /// @return true if the change is successful
  function updateAttribute(
    uint256 _tokenId,
    uint256 _index,
    uint8 _value
  ) public returns (bool) {
    if (isMutable(_tokenId, _index)) {
      _metadata[_tokenId].attributes[_index] = _value;
      return true;
    }
    return false;
  }

  /// @notice Changes the status
  /// @dev Throws if the sender is not an operator authorized in the contract. See above.
  /// @param _tokenId The id of the token for whom to change the attributes
  /// @param _shiftPosition The number of position to be left shifted
  /// For example, to change the transferability of token #12
  /// from 1 to 0, the operator contract should call
  ///    updateStatus(12, 1, 0);
  /// @param _newValue The bool must be converted in 1 or 0
  /// @return true if the change is successful
  function updateStatus(
    uint256 _tokenId,
    uint256 _shiftPosition,
    bool _newValue
  ) public returns (bool) {
    require(_shiftPosition <= _maxStatusShiftPosition, "status bit out of range");
    uint256 newValue;
    if (_newValue) {
      newValue = (1 << _shiftPosition) | _metadata[_tokenId].status;
    } else {
      newValue = (255 & (~(1 << _shiftPosition))) & _metadata[_tokenId].status;
    }
    _metadata[_tokenId].status = uint8(newValue);
    return true;
  }
}
