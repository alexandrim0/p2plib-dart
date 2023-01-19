part of 'data.dart';

enum P2PPacketType { regular, confirmable, confirmation }

/// 1 byte - forwards count
/// 1 byte - packet type
/// 6 bytes - issuedAt (unix timestamp with ms)
/// 8 bytes - message id (int)
class P2PPacketHeader {
  static const length = 16;

  static int resetForwardsCount(Uint8List datagram) {
    final forwardsCount = datagram[0];
    datagram[0] = 0;
    return forwardsCount;
  }

  static Uint8List setForwardsCount(int count, Uint8List datagram) {
    datagram[0] = count;
    return datagram;
  }

  final P2PPacketType messageType;
  final int issuedAt, id;
  final P2PFullAddress? srcFullAddress;
  final int forwardsCount;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        messageType,
        issuedAt,
        id,
      );

  @override
  bool operator ==(Object other) =>
      other is P2PPacketHeader &&
      runtimeType == other.runtimeType &&
      messageType == other.messageType &&
      issuedAt == other.issuedAt &&
      id == other.id;

  P2PPacketHeader({
    this.messageType = P2PPacketType.regular,
    final int? issuedAt,
    required this.id,
    this.srcFullAddress,
    this.forwardsCount = 0,
  }) : issuedAt = issuedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory P2PPacketHeader.fromBytes(
    final Uint8List datagram, [
    final P2PFullAddress? srcFullAddress,
  ]) {
    final messageType = datagram[1];
    if (messageType > P2PPacketType.values.length) {
      throw const FormatException('Packet type is wrong!');
    }
    final buffer = datagram.buffer.asInt64List(0, 2);
    return P2PPacketHeader(
      messageType: P2PPacketType.values[messageType],
      issuedAt: buffer[0] >> 16,
      id: buffer[1],
      srcFullAddress: srcFullAddress,
      forwardsCount: datagram[0],
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

  P2PPacketHeader copyWith({
    final int? issuedAt,
    final int? id,
    final P2PPacketType? messageType,
    final P2PFullAddress? srcFullAddress,
  }) =>
      P2PPacketHeader(
        messageType: messageType ?? this.messageType,
        issuedAt: issuedAt ?? this.issuedAt,
        id: id ?? this.id,
        srcFullAddress: srcFullAddress ?? this.srcFullAddress,
      );
}
