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

/// seed and publicKey is Uint8List(32), privateKey is Uint8List(64)
class P2PCryptoKeys {
  Uint8List? encSeed,
      encPublicKey,
      encPrivateKey,
      signSeed,
      signPublicKey,
      signPrivateKey;

  P2PCryptoKeys({
    this.encSeed,
    this.encPublicKey,
    this.encPrivateKey,
    this.signSeed,
    this.signPublicKey,
    this.signPrivateKey,
  });
}
