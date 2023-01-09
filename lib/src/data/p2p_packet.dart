part of 'data.dart';

class P2PPacket {
  final P2PPacketHeader header;
  final Uint8List datagram;

  const P2PPacket({required this.header, required this.datagram});
}
