part of 'data.dart';

enum P2PPacketType { regular, confirmable, acknowledgement }

/// 1 byte - protocol number
/// 1 byte - packet type
/// 6 bytes - issuedAt (unix timestamp with ms, int LE)
/// 8 bytes - message id (int LE)
class P2PPacketHeader {
  static const length = 16;
  static const maxProtocolNumber = 0;

  final P2PPacketType messageType;
  final int protocolNumber, issuedAt, id;
  final FullAddress? srcFullAddress;

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
    final FullAddress? srcFullAddress,
  ]) {
    if (datagram[0] > maxProtocolNumber) {
      throw const FormatException('Protocol number is wrong!');
    }
    final buffer = datagram.buffer.asInt64List(0, 2);
    return P2PPacketHeader(
      messageType: P2PPacketType.values[datagram[1]],
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
    head[0] = protocolNumber;
    head[1] = messageType.index;
    return head;
  }

  P2PPacketHeader copyWith({
    final int? protocolNumber,
    final int? issuedAt,
    final int? id,
    final P2PPacketType? messageType,
    final FullAddress? srcFullAddress,
  }) =>
      P2PPacketHeader(
        protocolNumber: protocolNumber ?? this.protocolNumber,
        messageType: messageType ?? this.messageType,
        issuedAt: issuedAt ?? this.issuedAt,
        id: id ?? this.id,
        srcFullAddress: srcFullAddress ?? this.srcFullAddress,
      );
}
