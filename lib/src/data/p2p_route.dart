part of 'data.dart';

class P2PRoute {
  static var maxStoredHeaders = 0;

  final P2PPeerId peerId;

  bool canForward;

  final _addresses = <P2PFullAddress, int>{};
  final _lastHeaders = QueueList<P2PPacketHeader>(maxStoredHeaders);

  P2PRoute({
    required this.peerId,
    this.canForward = false,
    final P2PPacketHeader? header,
    final Map<P2PFullAddress, int>? addresses,
    final MapEntry<P2PFullAddress, int>? address,
  }) {
    if (header != null) _lastHeaders.add(header);
    if (addresses != null) _addresses.addAll(addresses);
    if (address != null) _addresses[address.key] = address.value;
  }

  bool get isEmpty => addresses.isEmpty;
  bool get isNotEmpty => addresses.isNotEmpty;

  Map<P2PFullAddress, int> get addresses => _addresses;

  QueueList<P2PPacketHeader> get lastHeaders => _lastHeaders;

  int get lastSeen => addresses.isEmpty ? 0 : addresses.values.reduce(max);

  void addHeader(P2PPacketHeader header) {
    _lastHeaders.addLast(header);
    if (_lastHeaders.length > maxStoredHeaders) _lastHeaders.removeFirst();
  }

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

  Iterable<P2PFullAddress> getActualAddresses({required final int staleAt}) =>
      addresses.entries
          .where((e) => e.key.isStatic || e.value > staleAt)
          .map((e) => e.key);

  void removeStaleAddresses({required final int staleAt}) =>
      addresses.removeWhere((a, t) => a.isNotStatic && t < staleAt);
}
