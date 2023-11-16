part of 'router.dart';

/// Enhanced router with more high level API for building rich client

class RouterL2 extends RouterL1 {
  RouterL2({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  });
  final _lastSeenController = StreamController<PeerStatus>.broadcast();

  late Duration peerOnlineTimeout = retryPeriod * 2;

  Stream<PeerStatus> get lastSeenStream => _lastSeenController.stream;

  @override
  Future<Packet> onMessage(Packet packet) async {
    await super.onMessage(packet);

    // update peer status
    _lastSeenController.add((peerId: packet.srcPeerId, isOnline: true));

    return packet;
  }

  bool getPeerStatus(PeerId peerId) =>
      (routes[peerId]?.lastSeen ?? 0) + peerOnlineTimeout.inMilliseconds > _now;

  /// Add Address with port and timestamp for PeerId into cache
  void addPeerAddress({
    required PeerId peerId,
    required FullAddress address,
    required AddressProperties properties,
    bool? canForward,
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
        address: (ip: address, properties: properties),
      );
    }
  }

  void removePeerAddress(PeerId peerId) {
    if (routes.remove(peerId) != null) {
      _lastSeenController.add((peerId: peerId, isOnline: false));
    }
  }

  Future<bool> pingPeer(PeerId peerId) async {
    if (peerId == selfId) return true;
    try {
      await sendMessage(isConfirmable: true, dstPeerId: peerId);
      _lastSeenController.add((peerId: peerId, isOnline: true));
      return true;
    } catch (_) {}
    _lastSeenController.add((peerId: peerId, isOnline: getPeerStatus(peerId)));
    return false;
  }
}
