part of 'data.dart';

class P2PPacket {
  final P2PFullAddress srcFullAddress;
  final Uint8List datagram;
  final P2PPacketHeader header;
  P2PMessage? message;

  P2PPacket({
    required this.srcFullAddress,
    required this.datagram,
    required this.header,
  });
}
