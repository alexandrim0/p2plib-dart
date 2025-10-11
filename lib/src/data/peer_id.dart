part of 'data.dart';

/// A Peer ID is a 64-byte value composed of two 32-byte keys:
/// - An encryption key, used to encrypt messages sent to the peer.
/// - A signing key, used to sign messages sent by the peer.
class PeerId extends Token {
  static const _keyLength = 32;

  static const int length = _keyLength * 2;

  PeerId({required super.value}) {
    if (value.length != length) {
      throw const FormatException('PeerId length is invalid.');
    }
  }

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

    final builder = BytesBuilder(copy: false)
      ..add(encryptionKey)
      ..add(signKey);

    return PeerId(value: builder.toBytes());
  }

  Uint8List get encPublicKey => value.sublist(0, _keyLength);

  Uint8List get signPiblicKey => value.sublist(_keyLength, length);
}
