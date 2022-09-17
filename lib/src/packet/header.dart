import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../pubkey.dart';
import 'packet.dart';

enum Encrypted {
  no,
  encrypted,
  signed,
}

enum Ack { no, required }

class Header {
  static const int idLength = 16;

  final int topic;
  final Uint8List id;
  final PubKey srcKey;
  final PubKey dstKey;
  final Encrypted encrypted;
  final Ack ack;

  static const length =
      Packet.topicLength + PubKey.length + PubKey.length + 1 + idLength + 1;

  const Header(
      this.topic, this.id, this.srcKey, this.dstKey, this.encrypted, this.ack);

  factory Header.genId(
      int topic, PubKey srcKey, PubKey dstKey, Encrypted encrypted, Ack ack) {
    final uuid = Uuid();
    final id = Uint8List(idLength);
    uuid.v4buffer(id);
    return Header(topic, id, srcKey, dstKey, encrypted, ack);
  }

  factory Header.deserialize(Uint8List data) {
    final bytes = ByteData.view(data.buffer);
    if (bytes.lengthInBytes < length) {
      throw IncorrectPacketLength('Header');
    }

    int offset = 0;
    int topic = bytes.getUint64(offset);
    offset += Packet.topicLength;
    final Uint8List id = data.sublist(offset, offset + idLength);
    offset += idLength;
    final Uint8List srcKeyData = data.sublist(offset, offset + PubKey.length);
    PubKey srcKey = PubKey.keys(
        encryptionKey: srcKeyData.sublist(0, 32),
        signKey: srcKeyData.sublist(32));
    offset += PubKey.length;
    final Uint8List dstKeyData = data.sublist(offset, offset + PubKey.length);
    PubKey dstKey = PubKey.keys(
        encryptionKey: dstKeyData.sublist(0, 32),
        signKey: dstKeyData.sublist(32));
    offset += PubKey.length;
    final encrypted = Encrypted.values[bytes.getUint8(offset)];
    offset++;
    final ack = Ack.values[bytes.getUint8(offset)];

    return Header(topic, id, srcKey, dstKey, encrypted, ack);
  }

  Uint8List serialize() {
    ByteData bytes = ByteData(length);
    int offset = 0;
    bytes.setUint64(offset, topic);
    offset += Packet.topicLength;
    for (var i = 0; i < idLength; ++i) {
      bytes.setUint8(offset++, id[i]);
    }

    for (var byte in srcKey.data) {
      bytes.setUint8(offset++, byte);
    }
    for (var byte in dstKey.data) {
      bytes.setUint8(offset++, byte);
    }
    bytes.setUint8(offset++, encrypted.index);
    bytes.setUint8(offset++, ack.index);
    return bytes.buffer.asUint8List();
  }
}

class AckPacket {
  static const topic = 0;
  final Uint8List data;

  const AckPacket(this.data);
}
