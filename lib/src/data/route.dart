part of 'data.dart';

class Route {
  static var maxStoredHeaders = 0;

  final PeerId peerId;

  bool canForward;

  final _addresses = <FullAddress, int>{};
  final _lastHeaders = QueueList<PacketHeader>(maxStoredHeaders);

  Route({
    required this.peerId,
    this.canForward = false,
    final PacketHeader? header,
    final Map<FullAddress, int>? addresses,
    final MapEntry<FullAddress, int>? address,
  }) {
    if (header != null) _lastHeaders.add(header);
    if (addresses != null) _addresses.addAll(addresses);
    if (address != null) _addresses[address.key] = address.value;
  }

  bool get isEmpty => addresses.isEmpty;
  bool get isNotEmpty => addresses.isNotEmpty;

  Map<FullAddress, int> get addresses => _addresses;

  QueueList<PacketHeader> get lastHeaders => _lastHeaders;

  int get lastSeen => addresses.isEmpty ? 0 : addresses.values.reduce(max);

  void addHeader(PacketHeader header) {
    _lastHeaders.addLast(header);
    if (_lastHeaders.length > maxStoredHeaders) _lastHeaders.removeFirst();
  }

  void addAddress({
    required final FullAddress address,
    required final int timestamp,
    bool? canForward,
  }) {
    if (canForward != null) this.canForward = canForward;
    addresses[address] = timestamp;
  }

  void addAddresses({
    required final Iterable<FullAddress> addresses,
    required final int timestamp,
    bool? canForward,
  }) {
    if (canForward != null) this.canForward = canForward;
    for (final a in addresses) {
      this.addresses[a] = timestamp;
    }
  }

  Iterable<FullAddress> getActualAddresses({required final int staleAt}) =>
      addresses.entries
          .where((e) => e.key.isStatic || e.value > staleAt)
          .map((e) => e.key);

  void removeStaleAddresses({required final int staleAt}) =>
      addresses.removeWhere((a, t) => a.isNotStatic && t < staleAt);
}
