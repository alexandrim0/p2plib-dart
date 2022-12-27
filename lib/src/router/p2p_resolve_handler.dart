part of 'router.dart';

mixin P2PResolveHandler {
  final Map<P2PPeerId, Map<P2PFullAddress, int>> _cache = {};

  var peerAddressTTL = const Duration(minutes: 5);

  /// Returns cached addresses or who can forward
  Iterable<P2PFullAddress> resolvePeerId(final P2PPeerId peerId) =>
      getResolvedPeerId(peerId)?.keys ??
      _cache.values.fold<Set<P2PFullAddress>>(
        <P2PFullAddress>{},
        (previousValue, element) => previousValue.union(element.keys.toSet()),
      );

  /// Get cached resolved addresses for PeerId without stale
  Map<P2PFullAddress, int>? getResolvedPeerId(final P2PPeerId peerId) {
    final cachedAddresses = _cache[peerId];
    if (cachedAddresses == null || cachedAddresses.isEmpty) return null;
    final stale =
        DateTime.now().millisecondsSinceEpoch - peerAddressTTL.inMilliseconds;
    cachedAddresses.removeWhere((_, timestamp) => timestamp < stale);
    return cachedAddresses.isEmpty ? null : cachedAddresses;
  }

  /// Add Address with port and timestamp for PeerId into cache
  void addPeerAddress({
    required final P2PPeerId peerId,
    required final Iterable<P2PFullAddress> addresses,
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

  bool forgetPeerId(final P2PPeerId peerId) => _cache.remove(peerId) != null;

  void clearResolveCache() => _cache.clear();
}
