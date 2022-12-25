part of 'data.dart';

enum CryptoTaskType {
  seal,
  unseal,
  encrypt,
  decrypt,
  sign,
  openSigned,
}

class CryptoTask {
  final int id;
  final CryptoTaskType type;
  Object payload;
  Object? extra;

  CryptoTask({
    required this.id,
    required this.type,
    required this.payload,
    this.extra,
  });
}

class CryptoKeys {
  final Uint8List encPublicKey, encSeed, signPublicKey, signSeed;

  const CryptoKeys({
    required this.encPublicKey,
    required this.encSeed,
    required this.signPublicKey,
    required this.signSeed,
  });
}
