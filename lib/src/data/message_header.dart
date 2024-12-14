part of 'data.dart';

/// Represents the type of packet.
///
/// - `regular`: A standard packet that does not require acknowledgment.
/// - `confirmable`: A packet that requires an acknowledgment from the recipient.
/// - `confirmation`: A packet that serves as an acknowledgment for a confirmable packet.
enum PacketType { regular, confirmable, confirmation }

/// Structure of a packet header:
///
/// - 1 byte:  forwards count
/// - 1 byte:  packet type
/// - 6 bytes: issuedAt (Unix timestamp with milliseconds)
/// - 8 bytes: message id (int)
///
/// Total header length: 16 bytes

/// Represents the header of a network packet.
///
/// This class encapsulates the metadata associated with a packet, 
/// including its type, ID, timestamp, and forwarding information. 
/// It is immutable, meaning its properties cannot be changed after creation.
@immutable
class PacketHeader {
  /// The total length of the header in bytes.
  static const length = 16;

  /// Sets the forwards count in the datagram.
  ///
  /// [count] The forwards count to set.
  /// [datagram] The datagram to modify.
  ///
  /// Returns the modified datagram.
  static Uint8List setForwardsCount(int count, Uint8List datagram) {
    datagram[0] = count;
    return datagram;
  }

  /// Creates a new [PacketHeader] instance.
  ///
  /// [id] The unique identifier of the packet.
  /// [issuedAt] The timestamp when the packet was issued (Unix timestamp with milliseconds).
  /// [forwardsCount] The number of times the packet has been forwarded. Defaults to 0.
  /// [messageType] The type of the packet. Defaults to [PacketType.regular].
  const PacketHeader({
    required this.id,
    required this.issuedAt,
    this.forwardsCount = 0,
    this.messageType = PacketType.regular,
  });

  /// Creates a [PacketHeader] instance from a byte array.
  ///
  /// [datagram] The byte array containing the header data.
  ///
  /// Returns a new [PacketHeader] instance.
  ///
  /// Throws a [FormatException] if the packet type is invalid.
  factory PacketHeader.fromBytes(Uint8List datagram) {
    // Get the message type from the datagram.
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
  
  /// The timestamp when the packet was issued (Unix timestamp with milliseconds).
  final int issuedAt;
  
  /// The number of times the packet has been forwarded.
  final int forwardsCount;
  
  /// The type of the packet.
  final PacketType messageType;

  /// Overrides the `hashCode` method to generate a hash code based on the
  /// `runtimeType`, `issuedAt`, and `id` of the `PacketHeader`.
  ///
  /// This ensures that two `PacketHeader` instances with the same values for
  /// these properties will have the same hash code, which is essential for
  /// using them in hash-based data structures like hash maps.
  @override
  int get hashCode => Object.hash(runtimeType, issuedAt, id);

  /// Overrides the `==` operator to compare two `PacketHeader` instances for
  /// equality.
  ///
  /// Two `PacketHeader` instances are considered equal if they have the same
  /// `runtimeType`, `issuedAt`, and `id`. This method is used for comparison
  /// and equality checks.
  @override
  bool operator ==(Object other) =>
      other is PacketHeader &&
      runtimeType == other.runtimeType &&
      issuedAt == other.issuedAt &&
      id == other.id;

  /// Converts the `PacketHeader` to a byte array.
  ///
  /// This method serializes the `PacketHeader` instance into a byte array
  /// representation, which can be used for network transmission or storage.
  ///
  /// Returns a [Uint8List] containing the serialized header data.
  Uint8List toBytes() {
    // Create a new byte array with the length of the header.
    final head = Uint8List(16);
    
    // Set the `issuedAt` and `id` in the byte array using little-endian byte order.
    head.buffer.asByteData()
      ..setInt64(0, issuedAt << 16, Endian.little)
      ..setInt64(8, id, Endian.little);
    
    // Set the message type in the byte array.
    head[1] = messageType.index;
    
    // Return the byte array.
    return head;
  }

  /// Creates a copy of the `PacketHeader` with optional modifications.
  ///
  /// This method allows you to create a new `PacketHeader` instance based on
  /// the current one, with the option to modify specific properties.
  ///
  /// [issuedAt] The new value for the `issuedAt` property.
  /// [id] The new value for the `id` property.
  /// [messageType] The new value for the `messageType` property.
  ///
  /// Returns a new `PacketHeader` instance with the specified modifications.
  PacketHeader copyWith({
    int? issuedAt,
    int? id,
    PacketType? messageType,
  }) =>
      PacketHeader(
        messageType: messageType ?? this.messageType,
        issuedAt: issuedAt ?? this.issuedAt,
        id: id ?? this.id,
      );
}
