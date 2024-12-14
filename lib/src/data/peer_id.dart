part of 'data.dart';

/// Represents a Peer ID, which is used to uniquely identify a peer in the network.
///
/// A Peer ID is a 64-byte value composed of two 32-byte keys:
/// - An encryption key, used to encrypt messages sent to the peer.
/// - A signing key, used to sign messages sent by the peer.
///
/// This class ensures that each peer has a unique and verifiable identity within
/// the network.
class PeerId extends Token {
  /// The length of each key in bytes.
  /// This is a constant value of 32 bytes.
  static const _keyLength = 32;

  /// The total length of the Peer ID in bytes.
  /// This is a constant value of 64 bytes (2 * _keyLength).
  static const length = _keyLength * 2;

  /// Creates a new Peer ID from a byte array.
  ///
  /// [value] The byte array representing the Peer ID.
  ///
  /// Throws a [FormatException] if the byte array is not the correct length (64 bytes).
  PeerId({required super.value}) {
    if (value.length != length) {
      throw const FormatException('PeerId length is invalid.');
    }
  }

  /// Creates a new Peer ID from two keys: an encryption key and a signing key.
  ///
  /// [encryptionKey] The encryption key, used to encrypt messages sent to the peer.
  /// [signKey] The signing key, used to sign messages sent by the peer.
  ///
  /// Throws a [FormatException] if either key is not the correct length (32 bytes).
  factory PeerId.fromKeys({
    required Uint8List encryptionKey,
    required Uint8List signKey,
  }) {
    if (encryptionKey.length != _keyLength) {
      throw const FormatException('Encryption key length is invalid.');
    }
    if (signKey.length != _keyLength) {
      throw const FormatException('Signing key length is invalid.');
    }
    
    // Combine the encryption and signing keys into a single byte array.
    final builder = BytesBuilder(copy: false)
      ..add(encryptionKey)
      ..add(signKey);
    
    // Create and return a new PeerId instance.
    return PeerId(value: builder.toBytes());
  }

  /// Returns the encryption public key of the peer.
  ///
  /// This key is used to encrypt messages sent to the peer.
  Uint8List get encPublicKey => value.sublist(0, _keyLength);

  /// Returns the signing public key of the peer.
  ///
  /// This key is used to verify the signature of messages sent by the peer.
  Uint8List get signPiblicKey => value.sublist(_keyLength, length);
}
