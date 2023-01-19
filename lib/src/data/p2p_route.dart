part of 'data.dart';

class P2PRoute {
  final P2PPeerId peerId;
  final Map<P2PFullAddress, int> addresses = {};

  int lastseen;
  bool canForward;
  P2PFullAddress address;
  P2PPacketHeader? lastPacketHeader;

  P2PRoute({
    required this.peerId,
    required this.address,
    this.canForward = false,
  }) : lastseen = DateTime.now().millisecondsSinceEpoch {
    addresses[address] = lastseen;
  }
}
