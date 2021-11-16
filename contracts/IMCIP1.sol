// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IMCIP-1 On chain metadata
///  Version: 0.0.2
///  Note: the ERC-165 identifier for this interface is 0x079882ad.
interface IMCIP1 /* is ERC165 */{

  /// @dev Emitted when the metadata for a token id and a game is set.
  event MetadataSet(uint256 indexed _tokenId, address indexed _game, Metadata _metadata);

  /// @dev This struct saves info about the token.
  struct Metadata {
    // A game can change the way it manages the data, updating the version
    uint8 version;

    // status should be managed with bitwise operators
    // and it refers to the status of the token in a specific game
    uint8 status;
    // It supports a maximum of 8 properties managed with bitwise operators.
    // For now there are two proposed fields:
    //   name        value
    //   burnable    1                // for example a potion
    //   burned      1 << 1           // if burned on game A, it is still usable in game B
    // adding more is up the game.
    // If an NFT has been virtually burned, the property could be considered immutable.
    // However, in some other game, an NFT could be resuscitated (why not?)

    // list of attributes
    uint8[30] attributes;
    // Attributes can be immutable (for example because taken from the metadata.json)
    // or mutable, because they depends only on the game itself.
    // If a field requires more than 256 possible value, two bytes can be used for it.
  }

  /// @dev It returns the on-chain metadata of a specific token
  /// @param _tokenId The id of the token for whom to query the on-chain metadata
  /// @param _game The address of the game's contract
  /// @return The metadata of the token
  function metadataOf(uint256 _tokenId, address _game) external view returns (Metadata memory);

  /// @notice Initialize the attributes of a token
  /// @dev It must be called by a game's contract to initialize
  /// the metadata according to its own attributes. This function removes the
  /// need of an approveGame function, because initializing the metadata for a game,
  /// implies approving the game.
  /// @param _tokenId The id of the token for whom to change the attributes
  /// @param _version The version of the metadata
  /// @param _initialStatus The initial status (if, for example, it is burnable)
  /// @param _values The actual attributes
  /// @return true if the initialization is successful
  function initMetadata(
    uint256 _tokenId,
    uint8 _version,
    uint8 _initialStatus,
    uint8[30] memory _values
  ) external returns (bool);

  /// @notice Sets the attributes of a token after first set up
  /// @dev It modifies attributes by id for a specific game. It must
  /// be called by the game's contract, after an NFT has been initialized.
  /// @param _tokenId The id of the token for whom to change the attributes
  /// @param _indexes The indexes of the attributes to be changed
  /// @param _values The values of the attributes to be changed
  /// @return true if the change is successful
  function updateAttributes(
    uint256 _tokenId,
    uint8[] memory _indexes,
    uint8[] memory _values
  ) external returns (bool);

  /// @notice Changes the status
  /// @dev Acts on the metadata related to the specific game's contract.
  /// @param _tokenId The id of the token for whom to change the attributes
  /// @param _position The position of the property starting from the right
  /// For example, to burn token #12 in a specific game
  /// the game contract should call:  updateStatus(12, 1, 0);
  /// @param _newValue The bool must be converted in 1 or 0
  /// @return true if the change is successful
  function updateStatusProperty(
    uint256 _tokenId,
    uint256 _position,
    bool _newValue
  ) external returns (bool);

}
