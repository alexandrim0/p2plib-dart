import 'dart:typed_data';

enum EchoPacketType { request, response }

class EchoPacket {
  final EchoPacketType type;
  final Uint8List id;

  const EchoPacket(this.type, this.id);

  factory EchoPacket.deserialize(Uint8List data) {
    final type = EchoPacketType.values[data[0]];
    final body = data.sublist(1);
    return EchoPacket(type, body);
  }

  Uint8List serialize() {
    final builder = BytesBuilder();
    builder.add([type.index]);
    builder.add(id);
    return builder.toBytes();
  }
}
