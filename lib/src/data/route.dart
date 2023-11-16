part of 'data.dart';

class Route {
  static int maxStoredHeaders = 0;

  Route({
    required this.peerId,
    this.canForward = false,
    PacketHeader? header,
    Map<FullAddress, AddressProperties>? addresses,
    ({FullAddress ip, AddressProperties properties})? address,
  }) {
    if (header != null) _lastHeaders.add(header);
    if (addresses != null) _addresses.addAll(addresses);
    if (address != null) _addresses[address.ip] = address.properties;
  }

  final PeerId peerId;

  bool canForward;

  final _addresses = <FullAddress, AddressProperties>{};
  final _lastHeaders = QueueList<PacketHeader>(maxStoredHeaders);

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
    required FullAddress address,
    required AddressProperties properties,
    bool? canForward,
  }) {
    if (canForward != null) this.canForward = canForward;
    if (addresses.containsKey(address)) {
      addresses[address]!.combine(properties);
    } else {
      addresses[address] = properties;
    }
  }

  Iterable<FullAddress> getActualAddresses({required int staleAt}) =>
      addresses.entries
          .where((e) => e.value.isStatic || e.value.lastSeen > staleAt)
          .map((e) => e.key);

  void removeStaleAddresses({required int staleAt}) =>
      addresses.removeWhere((k, v) => v.isNotStatic && v.lastSeen < staleAt);

  @override
  String toString() =>
      '$peerId, canForward: $canForward, headersCount: ${_lastHeaders.length}\n'
      '$_addresses';
}
