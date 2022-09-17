import 'dart:typed_data';
import 'utils/utils.dart';
import 'raw_token.dart';

class PubKey extends RawToken {
  static const length = 64;

  PubKey(Uint8List data) : super(data: data, len: length);
  factory PubKey.keys(
          {required Uint8List encryptionKey, required Uint8List signKey}) =>
      PubKey(combineLists(encryptionKey, signKey));

  factory PubKey.zeros() => PubKey.keys(
      encryptionKey: randomBytes(length: 32), signKey: randomBytes(length: 32));

  Uint8List encryptionKey() {
    return data.sublist(0, 32);
  }

  Uint8List signKey() {
    return data.sublist(32, length);
  }
}
