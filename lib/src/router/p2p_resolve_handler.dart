part of 'router.dart';

mixin P2PResolveHandler {
  final Map<P2PPeerId, Map<P2PFullAddress, int>> _resolveCache = {};

  var peerAddressTTL = const Duration(seconds: 30);

  P2PPeerId get selfId;

  /// Returns cached addresses or who can forward
  Iterable<P2PFullAddress> resolvePeerId(final P2PPeerId peerId) =>
      getResolvedPeerId(peerId)?.keys ??
      _resolveCache.values.fold<Set<P2PFullAddress>>(
        <P2PFullAddress>{},
        (previousValue, element) => previousValue.union(element.keys.toSet()),
      );

  /// Get cached resolved addresses for PeerId without stale
  Map<P2PFullAddress, int>? getResolvedPeerId(final P2PPeerId peerId) {
    final cachedAddresses = _resolveCache[peerId];
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
    if (peerId == selfId) return;
    final cachedAddresses = _resolveCache[peerId] ?? {};
    for (final address in addresses) {
      cachedAddresses[address] =
          timestamp ?? DateTime.now().millisecondsSinceEpoch;
    }
    _resolveCache[peerId] = cachedAddresses;
  }

  bool forgetPeerId(final P2PPeerId peerId) =>
      _resolveCache.remove(peerId) != null;

  void clearResolveCache() => _resolveCache.clear();
}
