import 'dart:typed_data';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../packet/header.dart';

final _random = Random.secure();
final uuid = Uuid();

Uint8List randomBytes({int length = 32}) => Uint8List.fromList(
    Iterable.generate(length, (x) => _random.nextInt(255)).toList());

Uint8List combineLists(Uint8List first, Uint8List second) {
  final builder = BytesBuilder();
  builder.add(first);
  builder.add(second);
  return builder.toBytes();
}

Uint8List genPacketId() {
  final id = Uint8List(Header.idLength);
  uuid.v4buffer(id);
  return id;
}
