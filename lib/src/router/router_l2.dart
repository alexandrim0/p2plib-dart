part of 'router.dart';

/// Enhanced router with more high level API for building rich client

class RouterL2 extends RouterL1 {
  final _lastSeenController =
      StreamController<MapEntry<PeerId, bool>>.broadcast();

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

  /// Add Address with port and timestamp for PeerId into cache
  void addPeerAddress({
    required final PeerId peerId,
    required final FullAddress address,
    final bool? canForward,
    int? timestamp,
  }) {
    if (peerId == selfId) return;
    timestamp ??= _now;
    if (routes.containsKey(peerId)) {
      routes[peerId]!.addAddress(
        address: address,
        timestamp: timestamp,
        canForward: canForward,
      );
    } else {
      routes[peerId] = Route(
        peerId: peerId,
        canForward: canForward ?? false,
        address: MapEntry(address, timestamp),
      );
    }
  }

  /// Add Addresses with port and timestamp for PeerId into cache
  void addPeerAddresses({
    required final PeerId peerId,
    required final Iterable<FullAddress> addresses,
    final bool? canForward,
    int? timestamp,
  }) {
    if (addresses.isEmpty || peerId == selfId) return;
    timestamp ??= _now;
    if (routes.containsKey(peerId)) {
      routes[peerId]!.addAddresses(
        addresses: addresses,
        timestamp: timestamp,
        canForward: canForward,
      );
    } else {
      routes[peerId] = Route(
        peerId: peerId,
        canForward: canForward ?? false,
        addresses: {for (final a in addresses) a: timestamp},
      );
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
