part of 'data.dart';

/// 1 byte - forwards count
/// 1 byte - packet type
/// 6 bytes - issuedAt (unix timestamp with ms)
/// 8 bytes - message id (int)
/// 64 bytes - source PeerId
/// 64 bytes - destination PeerId
/// 0 | >48 bytes - encrypted payload
/// 64 bytes - signature

class Packet {
  final FullAddress srcFullAddress;
  final PacketHeader header;
  final Uint8List datagram;
  late final PeerId srcPeerId, dstPeerId;
  late final Uint8List payload;

  Packet({
    required this.srcFullAddress,
    required this.datagram,
    required this.header,
  });
}
