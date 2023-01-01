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
  Uint8List encSeed,
      encPublicKey,
      encPrivateKey,
      signSeed,
      signPublicKey,
      signPrivateKey;

  P2PCryptoKeys({
    required this.encSeed,
    required this.encPublicKey,
    required this.encPrivateKey,
    required this.signSeed,
    required this.signPublicKey,
    required this.signPrivateKey,
  });

  factory P2PCryptoKeys.empty() => P2PCryptoKeys(
        encSeed: emptyUint8List,
        encPublicKey: emptyUint8List,
        encPrivateKey: emptyUint8List,
        signSeed: emptyUint8List,
        signPublicKey: emptyUint8List,
        signPrivateKey: emptyUint8List,
      );
}
