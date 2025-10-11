part of 'data.dart';

/// Represents the type of packet.
///
/// - `regular`: A standard packet that does not require acknowledgment.
/// - `confirmable`: A packet that requires an acknowledgment from the recipient
/// - `confirmation`: A packet that serves as an acknowledgment
///                   for a confirmable packet.
enum PacketType { regular, confirmable, confirmation }

/// Structure of a packet header:
///
/// - 1 byte:  forwards count
/// - 1 byte:  packet type
/// - 6 bytes: issuedAt (Unix timestamp with milliseconds)
/// - 8 bytes: message id (int)
///
/// Total header length: 16 bytes
@immutable
class PacketHeader {
  static const length = 16;

  static Uint8List setForwardsCount(int count, Uint8List datagram) {
    datagram[0] = count;
    return datagram;
  }

  const PacketHeader({
    required this.id,
    required this.issuedAt,
    this.forwardsCount = 0,
    this.messageType = PacketType.regular,
  });

  factory PacketHeader.fromBytes(Uint8List datagram) {
    final messageType = datagram[1];

    // Validate the message type.
    if (messageType > PacketType.values.length) {
      throw const FormatException('Packet type is wrong!');
    }

    // Get the issuedAt and id from the datagram.
    final buffer = datagram.buffer.asInt64List(0, 2);

    // Create and return a new PacketHeader instance.
    return PacketHeader(
      forwardsCount: datagram[0],
      messageType: PacketType.values[messageType],
      issuedAt: buffer[0] >> 16,
      id: buffer[1],
    );
  }

  /// The unique identifier of the packet.
  final int id;

  /// The timestamp when the packet was issued
  /// (Unix timestamp with milliseconds).
  final int issuedAt;

  /// The number of times the packet has been forwarded.
  final int forwardsCount;

  /// The type of the packet.
  final PacketType messageType;

  @override
  int get hashCode => Object.hash(runtimeType, issuedAt, id);

  @override
  bool operator ==(Object other) =>
      other is PacketHeader &&
      runtimeType == other.runtimeType &&
      issuedAt == other.issuedAt &&
      id == other.id;

  Uint8List toBytes() {
    final head = Uint8List(16);

    head.buffer.asByteData()
      ..setInt64(0, issuedAt << 16, Endian.little)
      ..setInt64(8, id, Endian.little);

    head[1] = messageType.index;

    return head;
  }

  PacketHeader copyWith({
    int? issuedAt,
    int? id,
    PacketType? messageType,
  }) => PacketHeader(
    messageType: messageType ?? this.messageType,
    issuedAt: issuedAt ?? this.issuedAt,
    id: id ?? this.id,
  );
}
