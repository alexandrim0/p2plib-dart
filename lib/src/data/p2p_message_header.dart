part of 'data.dart';

enum P2PPacketType { regular, confirmable, confirmation }

/// 1 byte - forwards count
/// 1 byte - protocol number (4bit) / packet type (4bit)
/// 6 bytes - issuedAt (unix timestamp with ms)
/// 8 bytes - message id (int)
class P2PPacketHeader {
  static const length = 16;
  static const maxProtocolNumber = 0;

  /// Returns forwards count and set it to zero for checking signature
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
  final int protocolNumber, issuedAt, id;
  final P2PFullAddress? srcFullAddress;

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
      protocolNumber == other.protocolNumber &&
      messageType == other.messageType &&
      issuedAt == other.issuedAt &&
      id == other.id;

  P2PPacketHeader({
    this.protocolNumber = 0,
    this.messageType = P2PPacketType.regular,
    final int? issuedAt,
    required this.id,
    this.srcFullAddress,
  }) : issuedAt = issuedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory P2PPacketHeader.fromBytes(
    final Uint8List datagram, [
    final P2PFullAddress? srcFullAddress,
  ]) {
    final protocolNumber = datagram[1] >> 4;
    if (protocolNumber > maxProtocolNumber) {
      throw const FormatException('Protocol number is wrong!');
    }
    final messageType = datagram[1] & 0x0F;
    if (messageType > P2PPacketType.values.length) {
      throw const FormatException('Packet type is wrong!');
    }
    final buffer = datagram.buffer.asInt64List(0, 2);
    return P2PPacketHeader(
      messageType: P2PPacketType.values[messageType],
      issuedAt: buffer[0] >> 16,
      id: buffer[1],
      srcFullAddress: srcFullAddress,
    );
  }

  Uint8List toBytes() {
    final head = Uint8List(16);
    head.buffer.asByteData()
      ..setInt64(0, issuedAt << 16, Endian.little)
      ..setInt64(8, id, Endian.little);
    head[1] = messageType.index | (protocolNumber << 4);
    return head;
  }

  P2PPacketHeader copyWith({
    final int? protocolNumber,
    final int? issuedAt,
    final int? id,
    final P2PPacketType? messageType,
    final P2PFullAddress? srcFullAddress,
  }) =>
      P2PPacketHeader(
        protocolNumber: protocolNumber ?? this.protocolNumber,
        messageType: messageType ?? this.messageType,
        issuedAt: issuedAt ?? this.issuedAt,
        id: id ?? this.id,
        srcFullAddress: srcFullAddress ?? this.srcFullAddress,
      );
}
