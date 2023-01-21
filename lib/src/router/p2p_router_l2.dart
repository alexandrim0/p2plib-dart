part of 'router.dart';

class P2PRouterL2 extends P2PRouterL1 {
  final _lastSeenController =
      StreamController<MapEntry<P2PPeerId, bool>>.broadcast();

  Stream<MapEntry<P2PPeerId, bool>> get lastSeenStream =>
      _lastSeenController.stream;

  P2PRouterL2({
    super.crypto,
    super.transports,
    super.debugLabel,
    super.logger,
  });

  /// returns null if message is processed and children have to return
  @override
  Future<P2PPacket?> onMessage(final P2PPacket packet) async {
    // exit if parent done all needed work
    if (await super.onMessage(packet) == null) return null;
    final srcPeerId = P2PMessage.getSrcPeerId(packet.datagram);
    _lastSeenController.add(MapEntry<P2PPeerId, bool>(srcPeerId, true));
    return packet;
  }

  /// Add Address with port and timestamp for PeerId into cache
  void addPeerAddresses({
    required final P2PPeerId peerId,
    required final Iterable<P2PFullAddress> addresses,
    bool canForward = false,
    int? timestamp,
  }) {
    if (addresses.isEmpty) return;
    if (peerId == selfId) return;
    timestamp ??= DateTime.now().millisecondsSinceEpoch;
    if (routes.containsKey(peerId)) {
      routes[peerId]!.addAddresses(
        addresses: addresses,
        timestamp: timestamp,
        canForward: canForward,
      );
    } else {
      routes[peerId] = P2PRoute(
        peerId: peerId,
        canForward: canForward,
        addresses: {for (final a in addresses) a: timestamp},
      );
    }
  }

  bool getPeerStatus(final P2PPeerId peerId) =>
      (routes[peerId]?.lastSeen ?? 0) + requestTimeout.inMilliseconds >
      DateTime.now().millisecondsSinceEpoch;

  Future<bool> pingPeer(final P2PPeerId peerId) async {
    try {
      await sendMessage(isConfirmable: true, dstPeerId: peerId);
      _lastSeenController.add(MapEntry<P2PPeerId, bool>(peerId, true));
      return true;
    } catch (_) {}
    _lastSeenController.add(MapEntry<P2PPeerId, bool>(
      peerId,
      getPeerStatus(peerId),
    ));
    return false;
  }
}
