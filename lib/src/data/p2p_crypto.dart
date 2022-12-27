part of 'data.dart';

enum P2PCryptoTaskType {
  seal,
  unseal,
  encrypt,
  decrypt,
  sign,
  openSigned,
}

class P2PCryptoTask {
  final int id;
  final P2PCryptoTaskType type;
  Object payload;
  Object? extra;

  P2PCryptoTask({
    required this.id,
    required this.type,
    required this.payload,
    this.extra,
  });
}

class P2PCryptoKeys {
  final Uint8List encPublicKey, encSeed, signPublicKey, signSeed;

  const P2PCryptoKeys({
    required this.encPublicKey,
    required this.encSeed,
    required this.signPublicKey,
    required this.signSeed,
  });
}
