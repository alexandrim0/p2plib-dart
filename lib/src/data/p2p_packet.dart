part of 'data.dart';

// TBD: add srcPeerId to prevent parse twice?
// TBD: use P2PPacketBase and children P2PPacketL0..2 ?
class P2PPacket {
  final P2PFullAddress srcFullAddress;
  final P2PPacketHeader header;
  final Uint8List datagram;

  const P2PPacket({
    required this.header,
    required this.datagram,
    required this.srcFullAddress,
  });
}
