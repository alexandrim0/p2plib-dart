part of 'data.dart';

enum PacketType { regular, confirmable, confirmation }

/// 1 byte - forwards count
/// 1 byte - packet type
/// 6 bytes - issuedAt (unix timestamp with ms)
/// 8 bytes - message id (int)

class PacketHeader {
  static const length = 16;

  static Uint8List setForwardsCount(int count, Uint8List datagram) {
    datagram[0] = count;
    return datagram;
  }

  final PacketType messageType;
  final int forwardsCount, issuedAt, id;

  const PacketHeader({
    this.forwardsCount = 0,
    this.messageType = PacketType.regular,
    required this.issuedAt,
    required this.id,
  });

  @override
  int get hashCode => Object.hash(runtimeType, issuedAt, id);

  @override
  bool operator ==(Object other) =>
      other is PacketHeader &&
      runtimeType == other.runtimeType &&
      issuedAt == other.issuedAt &&
      id == other.id;

  factory PacketHeader.fromBytes(final Uint8List datagram) {
    final messageType = datagram[1];
    if (messageType > PacketType.values.length) {
      throw const FormatException('Packet type is wrong!');
    }
    final buffer = datagram.buffer.asInt64List(0, 2);
    return PacketHeader(
      forwardsCount: datagram[0],
      messageType: PacketType.values[messageType],
      issuedAt: buffer[0] >> 16,
      id: buffer[1],
    );
  }

  Uint8List toBytes() {
    final head = Uint8List(16);
    head.buffer.asByteData()
      ..setInt64(0, issuedAt << 16, Endian.little)
      ..setInt64(8, id, Endian.little);
    head[1] = messageType.index;
    return head;
  }

  PacketHeader copyWith({
    final int? issuedAt,
    final int? id,
    final PacketType? messageType,
  }) =>
      PacketHeader(
        messageType: messageType ?? this.messageType,
        issuedAt: issuedAt ?? this.issuedAt,
        id: id ?? this.id,
      );
}
