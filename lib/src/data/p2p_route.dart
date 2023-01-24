part of 'data.dart';

class P2PRoute {
  final P2PPeerId peerId;

  bool canForward;
  Map<P2PFullAddress, int> addresses;
  P2PPacketHeader? lastPacketHeader;

  bool get isEmpty => addresses.isEmpty;
  bool get isNotEmpty => addresses.isNotEmpty;

  int get lastSeen => addresses.isEmpty ? 0 : addresses.values.reduce(max);

  P2PRoute({
    required this.peerId,
    this.canForward = false,
    this.lastPacketHeader,
    Map<P2PFullAddress, int>? addresses,
  }) : addresses = addresses ?? {};

  void addAddress({
    required final P2PFullAddress address,
    required final int timestamp,
    bool? canForward,
  }) {
    if (canForward != null) this.canForward = canForward;
    addresses[address] = timestamp;
  }

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

  Iterable<P2PFullAddress> getActualAddresses({required int staleAt}) =>
      addresses.entries.where((e) => e.value > staleAt).map((e) => e.key);

  void removeStaleAddresses({required int staleAt}) =>
      addresses.removeWhere((_, t) => t > staleAt);

  void dropStalePacketHeader({required int staleAt}) {
    if (lastSeen < staleAt) lastPacketHeader = null;
  }
}
