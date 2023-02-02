part of 'data.dart';

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
