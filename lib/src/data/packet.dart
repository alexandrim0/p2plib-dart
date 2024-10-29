part of 'data.dart';

/// Represents a network packet.
///
/// A packet consists of a header, source and destination Peer IDs, an optional
/// encrypted payload, and a signature. It is the fundamental unit of data
/// transmitted over the network.
///
/// Packet Structure:
/// - 1 byte:  Forwards count (number of times the packet has been forwarded)
/// - 1 byte:  Packet type (regular, confirmable, confirmation)
/// - 6 bytes: IssuedAt (Unix timestamp with milliseconds)
/// - 8 bytes: Message ID (unique identifier of the message)
/// - 64 bytes: Source Peer ID (identifier of the sending peer)
/// - 64 bytes: Destination Peer ID (identifier of the receiving peer)
/// - 0 or >48 bytes: Encrypted payload (optional data, encrypted for security)
/// - 64 bytes: Signature (used for message authentication)
class Packet {
  /// Creates a new [Packet] instance.
  ///
  /// [srcFullAddress] The full network address of the source peer.
  /// [datagram] The raw datagram data of the packet.
  /// [header] The header of the packet containing metadata.
  Packet({
    required this.srcFullAddress,
    required this.datagram,
    required this.header,
  });

  /// The full network address of the source peer.
  ///
  /// This property represents the address and port of the peer that sent
  /// the packet.
  final FullAddress srcFullAddress;

  /// The header of the packet.
  ///
  /// This property contains metadata about the packet, such as its type, ID,
  /// timestamp, and forwarding information.
  final PacketHeader header;

  /// The raw datagram data of the packet.
  ///
  /// This property represents the raw bytes of the packet as received from
  /// the network.
  final Uint8List datagram;

  /// The source Peer ID.
  ///
  /// This property represents the unique identifier of the peer that sent
  /// the packet.
  late final PeerId srcPeerId;

  /// The destination Peer ID.
  ///
  /// This property represents the unique identifier of the peer to which the
  /// packet is addressed.
  late final PeerId dstPeerId;

  /// The encrypted payload of the packet.
  ///
  /// This property represents the optional encrypted data carried by the
  /// packet. It may be empty if the packet does not contain any payload.
  late final Uint8List payload;
}
