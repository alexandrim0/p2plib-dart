part of 'router.dart';

/// Enhanced router with more high level API for building rich client

class RouterL2 extends RouterL1 {
  final _lastSeenController =
      StreamController<MapEntry<PeerId, bool>>.broadcast();

  late var peerOnlineTimeout = retryPeriod * 2;

  RouterL2({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.logger,
  });

  Stream<MapEntry<PeerId, bool>> get lastSeenStream =>
      _lastSeenController.stream;

  @override
  Future<Packet> onMessage(final Packet packet) async {
    await super.onMessage(packet);

    // update peer status
    _lastSeenController.add(MapEntry<PeerId, bool>(packet.srcPeerId, true));

    return packet;
  }

  bool getPeerStatus(final PeerId peerId) =>
      (routes[peerId]?.lastSeen ?? 0) + peerOnlineTimeout.inMilliseconds > _now;

  /// Add Address with port and timestamp for PeerId into cache
  void addPeerAddress({
    required final PeerId peerId,
    required final FullAddress address,
    required final AddressProperties properties,
    final bool? canForward,
  }) {
    if (peerId == selfId) return;
    if (routes.containsKey(peerId)) {
      routes[peerId]!.addAddress(
        address: address,
        properties: properties,
        canForward: canForward,
      );
    } else {
      routes[peerId] = Route(
        peerId: peerId,
        canForward: canForward ?? false,
        address: MapEntry(address, properties),
      );
    }
  }

  void removePeerAddress(PeerId peerId) {
    if (routes.remove(peerId) != null) {
      _lastSeenController.add(MapEntry<PeerId, bool>(peerId, false));
    }
  }

  Future<bool> pingPeer(final PeerId peerId) async {
    try {
      await sendMessage(isConfirmable: true, dstPeerId: peerId);
      _lastSeenController.add(MapEntry<PeerId, bool>(peerId, true));
      return true;
    } catch (_) {}
    _lastSeenController.add(MapEntry<PeerId, bool>(
      peerId,
      getPeerStatus(peerId),
    ));
    return false;
  }
}
