import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';

export 'dart:typed_data' show Uint8List;

part 'route.dart';
part 'token.dart';
part 'crypto.dart';
part 'peer_id.dart';
part 'message.dart';
part 'packet.dart';
part 'exception.dart';
part 'full_address.dart';
part 'message_header.dart';
part 'address_properties.dart';

typedef PeerStatus = ({PeerId peerId, bool isOnline});

final emptyUint8List = Uint8List(0);

int genRandomInt() =>
    (_random.nextInt(_maxRandomNumber) << 32) |
    _random.nextInt(_maxRandomNumber);

Uint8List getRandomBytes(int length) {
  final r = Uint8List(length);
  for (var i = 0; i < length; i++) {
    r[i] = _random.nextInt(255);
  }
  return r;
}

const _maxRandomNumber = 1 << 32;

final _random = Random.secure();
