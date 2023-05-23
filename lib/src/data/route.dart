part of 'data.dart';

class Route {
  static var maxStoredHeaders = 0;

  final PeerId peerId;

  bool canForward;

  final _addresses = <FullAddress, AddressProperties>{};
  final _lastHeaders = QueueList<PacketHeader>(maxStoredHeaders);

  Route({
    required this.peerId,
    this.canForward = false,
    final PacketHeader? header,
    final Map<FullAddress, AddressProperties>? addresses,
    final ({FullAddress ip, AddressProperties properties})? address,
  }) {
    if (header != null) _lastHeaders.add(header);
    if (addresses != null) _addresses.addAll(addresses);
    if (address != null) _addresses[address.ip] = address.properties;
  }

  bool get isEmpty => addresses.isEmpty;
  bool get isNotEmpty => addresses.isNotEmpty;

  Map<FullAddress, AddressProperties> get addresses => _addresses;

  QueueList<PacketHeader> get lastHeaders => _lastHeaders;

  int get lastSeen => addresses.isEmpty
      ? 0
      : addresses.values.map((e) => e.lastSeen).reduce(max);

  void addHeader(PacketHeader header) {
    _lastHeaders.addLast(header);
    if (_lastHeaders.length > maxStoredHeaders) _lastHeaders.removeFirst();
  }

  void addAddress({
    required final FullAddress address,
    required final AddressProperties properties,
    final bool? canForward,
  }) {
    if (canForward != null) this.canForward = canForward;
    if (addresses.containsKey(address)) {
      addresses[address]!.combine(properties);
    } else {
      addresses[address] = properties;
    }
  }

  Iterable<FullAddress> getActualAddresses({required final int staleAt}) =>
      addresses.entries
          .where((e) => e.value.isStatic || e.value.lastSeen > staleAt)
          .map((e) => e.key);

  void removeStaleAddresses({required final int staleAt}) =>
      addresses.removeWhere((k, v) => v.isNotStatic && v.lastSeen < staleAt);

  @override
  String toString() =>
      '$peerId, canForward: $canForward, headersCount: ${_lastHeaders.length}\n'
      '$_addresses';
}
