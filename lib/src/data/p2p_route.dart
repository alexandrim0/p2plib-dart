part of 'data.dart';

class P2PRoute {
  final P2PPeerId peerId;

  bool canForward;
  Map<P2PFullAddress, int> addresses;
  P2PPacketHeader? lastPacketHeader; // TBD: decide use or drop

  bool get isEmpty => addresses.isEmpty;
  bool get isNotEmpty => addresses.isNotEmpty;

  int get lastSeen => addresses.isEmpty ? 0 : addresses.values.reduce(max);

  P2PRoute({
    required this.peerId,
    this.canForward = false,
    this.lastPacketHeader,
    Map<P2PFullAddress, int>? addresses,
  }) : addresses = addresses ?? {};

  Iterable<P2PFullAddress> getActualAddresses({required int staleBefore}) =>
      addresses.entries.where((e) => e.value > staleBefore).map((e) => e.key);

  void addAddresses({
    required final Iterable<P2PFullAddress> addresses,
    required final int timestamp,
    bool? canForward,
  }) {
    if (canForward != null) this.canForward = canForward;
    for (final a in addresses) {
      this.addresses[a] = timestamp;
    }
  }
}
