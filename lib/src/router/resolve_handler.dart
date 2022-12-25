part of 'router.dart';

mixin ResolveHandler {
  final Map<PeerId, Map<FullAddress, int>> _cache = {};

  var peerAddressTTL = const Duration(minutes: 5);

  /// Returns cached addresses or who can forward
  Iterable<FullAddress> resolvePeerId(final PeerId peerId) =>
      getResolvedPeerId(peerId)?.keys ??
      _cache.values.fold<Set<FullAddress>>(
        <FullAddress>{},
        (previousValue, element) => previousValue.union(element.keys.toSet()),
      );

  /// Get cached resolved addresses for PeerId without stale
  Map<FullAddress, int>? getResolvedPeerId(final PeerId peerId) {
    final cachedAddresses = _cache[peerId];
    if (cachedAddresses == null || cachedAddresses.isEmpty) return null;
    final stale =
        DateTime.now().millisecondsSinceEpoch - peerAddressTTL.inMilliseconds;
    cachedAddresses.removeWhere((_, timestamp) => timestamp < stale);
    return cachedAddresses.isEmpty ? null : cachedAddresses;
  }

  /// Add Address with port and timestamp for PeerId into cache
  void addPeerAddress({
    required final PeerId peerId,
    required final Iterable<FullAddress> addresses,
    final int? timestamp,
  }) {
    if (addresses.isEmpty) return;
    final cachedAddresses = _cache[peerId] ?? {};
    for (final address in addresses) {
      cachedAddresses[address] =
          timestamp ?? DateTime.now().millisecondsSinceEpoch;
    }
    _cache[peerId] = cachedAddresses;
  }

  void clearCache() => _cache.clear();
}
