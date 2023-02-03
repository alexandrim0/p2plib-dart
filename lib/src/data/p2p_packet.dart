part of 'data.dart';

/// 1 byte - forwards count
/// 1 byte - packet type
/// 6 bytes - issuedAt (unix timestamp with ms)
/// 8 bytes - message id (int)
/// 64 bytes - source PeerId
/// 64 bytes - destination PeerId
/// 0 | >48 bytes - encrypted payload
/// 64 bytes - signature

class P2PPacket {
  final P2PFullAddress srcFullAddress;
  final P2PPacketHeader header;
  final Uint8List datagram;
  P2PPeerId? srcPeerId, dstPeerId;
  P2PMessage? message;

  P2PPacket({
    required this.srcFullAddress,
    required this.datagram,
    required this.header,
  });
}
