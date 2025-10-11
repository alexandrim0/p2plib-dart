part of 'data.dart';

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
  Packet({
    required this.srcFullAddress,
    required this.datagram,
    required this.header,
  });

  final FullAddress srcFullAddress;

  final PacketHeader header;

  final Uint8List datagram;

  late final PeerId srcPeerId;

  late final PeerId dstPeerId;

  late final Uint8List payload;
}
