import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:collection/collection.dart';

export 'dart:typed_data' show Uint8List;

part 'p2p_token.dart';
part 'p2p_crypto.dart';
part 'p2p_peer_id.dart';
part 'p2p_message.dart';
part 'p2p_datagram.dart';
part 'p2p_full_address.dart';
part 'p2p_message_header.dart';

const _maxRandomNumber = 1 << 32;
final _random = Random.secure();
final emptyUint8List = Uint8List(0);

int genRandomInt() =>
    (_random.nextInt(_maxRandomNumber) << 32) |
    _random.nextInt(_maxRandomNumber);

Uint8List getRandomBytes(final int length) {
  final r = Uint8List(length);
  for (var i = 0; i < length; i++) {
    r[i] = _random.nextInt(255);
  }
  return r;
}
