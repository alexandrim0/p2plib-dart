part of 'data.dart';

/// Represents a route to a peer in the network.
///
/// A route encapsulates information about how to reach a specific peer,
/// including its ID, addresses, and whether it can forward messages.
/// It is used by the router to determine the best path for delivering messages
/// to a given destination.
class Route {
  /// The maximum number of headers to store for the route.
  ///
  /// This value limits the number of recent headers kept in memory for
  /// tracking communication history with the peer.
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

  /// The unique identifier of the peer associated with this route.
  final PeerId peerId;

  /// Whether the peer can forward messages to other peers.
  bool canForward;

  /// The addresses associated with the peer, stored as a map of
  final _addresses = <FullAddress, AddressProperties>{};

  /// The last headers received from the peer, stored as a [QueueList].
  ///
  /// The list is limited to [maxStoredHeaders] entries to prevent
  /// excessive memory usage.
  final _lastHeaders = QueueList<PacketHeader>(maxStoredHeaders);

  /// Whether the route is empty (has no addresses).
  ///
  /// An empty route indicates that the peer is currently unreachable.
  bool get isEmpty => addresses.isEmpty;

  /// Whether the route is not empty (has at least one address).
  ///
  /// A non-empty route indicates that the peer is potentially reachable.
  bool get isNotEmpty => addresses.isNotEmpty;

  /// The addresses associated with the peer.
  ///
  /// This property provides access to the map of known addresses for the peer.
  Map<FullAddress, AddressProperties> get addresses => _addresses;

  /// The last headers received from the peer.
  ///
  /// This property provides access to the list of recent headers received
  /// from the peer.
  QueueList<PacketHeader> get lastHeaders => _lastHeaders;

  /// The last time the peer was seen (in milliseconds since epoch).
  ///
  /// This value is derived from the `lastSeen` property of the most recently
  /// seen address for the peer.
  ///
  /// Returns 0 if the peer has not been seen.
  int get lastSeen => addresses.isEmpty
      ? 0
      : addresses.values.map((e) => e.lastSeen).reduce(max);

  /// Adds a header to the route's header history.
  ///
  /// [header] The [PacketHeader] to add.
  ///
  /// If the header history exceeds [maxStoredHeaders], the oldest header is
  /// removed to maintain the size limit.
  void addHeader(PacketHeader header) {
    _lastHeaders.addLast(header);
    if (_lastHeaders.length > maxStoredHeaders) _lastHeaders.removeFirst();
  }

  /// Adds an address to the route.
  ///
  /// [address] The [FullAddress] to add to the route.
  /// [properties] The [AddressProperties] associated with the address.
  /// [canForward] An optional boolean value indicating whether the peer
  ///   associated with this address can forward messages. If provided,
  ///   it updates the `canForward` property of the route.
  void addAddress({
    required FullAddress address,
    required AddressProperties properties,
    bool? canForward,
  }) {
    if (canForward != null) this.canForward = canForward;
    if (addresses.containsKey(address)) {
      // If the address already exists, update its properties.
      addresses[address]!.combine(properties);
    } else {
      // If the address is new, add it to the route.
      addresses[address] = properties;
    }
  }

  /// Returns the actual addresses for the route, filtering out stale addresses.
  ///
  /// [staleAt] The timestamp (in milliseconds since epoch) after which an
  ///   address is considered stale.
  ///
  /// Returns an iterable of [FullAddress] objects representing the actual,
  ///   non-stale addresses associated with the route.
  Iterable<FullAddress> getActualAddresses({required int staleAt}) => addresses
      .entries
      .where((e) => e.value.isStatic || e.value.lastSeen > staleAt)
      .map((e) => e.key);

  /// Removes stale addresses from the route.
  ///
  /// [staleAt] The timestamp (in milliseconds since epoch) after which an
  ///   address is considered stale.
  ///
  /// This method removes addresses that are not static and have a `lastSeen`
  /// timestamp earlier than the specified `staleAt` value.
  void removeStaleAddresses({required int staleAt}) =>
      addresses.removeWhere((k, v) => v.isNotStatic && v.lastSeen < staleAt);

  @override
  String toString() =>
      '$peerId, canForward: $canForward, headersCount: ${_lastHeaders.length}\n'
      '$_addresses';
}
