part of 'data.dart';

const sealLength = 48;
const signatureLength = 64;

enum CryptoTaskType {
  seal,
  unseal,
  sign,
  verifySigned,
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

/// seed, public keys and encPrivateKey is Uint8List(32)
/// signPrivateKey is Uint8List(64)
class CryptoKeys {
  Uint8List seed, encPublicKey, encPrivateKey, signPublicKey, signPrivateKey;

  CryptoKeys({
    required this.seed,
    required this.encPublicKey,
    required this.encPrivateKey,
    required this.signPublicKey,
    required this.signPrivateKey,
  });

  factory CryptoKeys.empty() => CryptoKeys(
        seed: emptyUint8List,
        encPublicKey: emptyUint8List,
        encPrivateKey: emptyUint8List,
        signPublicKey: emptyUint8List,
        signPrivateKey: emptyUint8List,
      );
}
