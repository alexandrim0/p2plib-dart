part of 'data.dart';

enum P2PCryptoTaskType {
  seal,
  unseal,
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

/// seed, public keys and encPrivateKey is Uint8List(32)
/// signPrivateKey is Uint8List(64)
class P2PCryptoKeys {
  Uint8List seed, encPublicKey, encPrivateKey, signPublicKey, signPrivateKey;

  P2PCryptoKeys({
    required this.seed,
    required this.encPublicKey,
    required this.encPrivateKey,
    required this.signPublicKey,
    required this.signPrivateKey,
  });

  factory P2PCryptoKeys.empty() => P2PCryptoKeys(
        seed: emptyUint8List,
        encPublicKey: emptyUint8List,
        encPrivateKey: emptyUint8List,
        signPublicKey: emptyUint8List,
        signPrivateKey: emptyUint8List,
      );
}
