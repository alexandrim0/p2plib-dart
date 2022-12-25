part of 'data.dart';

class PeerId extends Token {
  static const _keyLength = 32;
  static const length = _keyLength * 2;

  PeerId({required super.value}) {
    if (value.length != length) const FormatException('PeerId length');
  }

  factory PeerId.fromKeys({
    required final Uint8List encryptionKey,
    required final Uint8List signKey,
  }) {
    final builder = BytesBuilder()
      ..add(encryptionKey)
      ..add(signKey);
    return PeerId(value: builder.toBytes());
  }

  Uint8List get encPublicKey => value.sublist(0, _keyLength);

  Uint8List get signPiblicKey => value.sublist(_keyLength, length);
}
