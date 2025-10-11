part of 'router.dart';

/// Enhanced router with more high-level API for building rich client
/// applications.
///
/// This class extends the functionality of `RouterL1` by providing a
/// higher-level API for managing peer connections and monitoring peer status.
/// It is designed to simplify the development of client applications that
/// require real-time communication and peer discovery.
class RouterL2 extends RouterL1 {
  RouterL2({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  });

  /// A stream controller for broadcasting peer status updates.
  ///
  /// This controller is used to publish updates about the online/offline
  /// status of peers. Subscribers to the `lastSeenStream` can receive these
  /// updates in real-time.
  final _lastSeenController = StreamController<PeerStatus>.broadcast();

  /// The timeout period for considering a peer offline.
  ///
  /// If a peer has not been seen for this duration, it is considered
  /// offline. This value is used by the `getPeerStatus` method to determine
  /// the online/offline status of a peer.
  late Duration peerOnlineTimeout = retryPeriod * 2;

  /// A stream of peer status updates.
  ///
  /// This stream provides real-time updates about the online/offline status
  /// of peers. Subscribers to this stream can be notified when a peer's
  /// status changes.
  Stream<PeerStatus> get lastSeenStream => _lastSeenController.stream;

  /// Handles incoming packets.
  ///
  /// This method is called when a new packet is received. It first calls the
  /// superclass's `onMessage` method to handle the packet. Then, it updates
  /// the peer status to online and returns the packet.
  ///
  /// [packet] The incoming packet.
  ///
  /// Returns the incoming packet.
  @override
  Future<Packet> onMessage(Packet packet) async {
    await super.onMessage(packet);

    // Update the peer status to online.
    _lastSeenController.add((peerId: packet.srcPeerId, isOnline: true));

    return packet;
  }

  /// Returns the status of a peer.
  ///
  /// This method checks if a peer is considered online based on the last
  /// time it was seen and the configured `peerOnlineTimeout`.
  ///
  /// [peerId] The ID of the peer to check.
  ///
  /// Returns `true` if the peer is online, `false` otherwise.
  bool getPeerStatus(PeerId peerId) =>
      (routes[peerId]?.lastSeen ?? 0) + peerOnlineTimeout.inMilliseconds >
      _now; // Check if peer has been seen recently

  /// Adds an address for a peer to the routing table.
  ///
  /// This method adds an address for a peer to the routing table. If the peer
  /// already exists in the routing table, the new address is added to the
  /// list of addresses for the peer. Otherwise, a new route is created for
  /// the peer with the new address.
  ///
  /// The [peerId] parameter specifies the ID of the peer.
  /// The [address] parameter specifies the address to add.
  /// The [properties] parameter specifies the properties of the address.
  /// The [canForward] parameter specifies whether the peer can forward
  ///   messages.
  void addPeerAddress({
    required PeerId peerId,
    required FullAddress address,
    required AddressProperties properties,
    bool? canForward,
  }) {
    // Ignore self.
    if (peerId == selfId) {
      return;
    }

    // If peer already exists in routing table.
    if (routes.containsKey(peerId)) {
      // Add the new address to the existing route.
      routes[peerId]!.addAddress(
        address: address,
        properties: properties,
        canForward: canForward,
      );
    } else {
      // Create a new route for the peer.
      routes[peerId] = Route(
        peerId: peerId,
        canForward: canForward ?? false,
        address: (ip: address, properties: properties),
      );
    }
  }

  /// Removes the peer address from the routing table.
  ///
  /// This method removes the peer address from the routing table. If the peer
  /// is removed from the routing table, the last seen controller is updated
  /// to indicate that the peer is offline.
  ///
  /// The [peerId] parameter specifies the ID of the peer to remove.
  void removePeerAddress(PeerId peerId) {
    // Remove the peer from the routing table.
    if (routes.remove(peerId) != null) {
      // Update the last seen controller to indicate that the peer is
      // offline.
      _lastSeenController.add((peerId: peerId, isOnline: false));
    }
  }

  /// Pings a peer to check if it is online.
  ///
  /// This method sends a ping message to the specified peer and waits for a
  /// response. If a response is received within the timeout period, the peer
  /// is considered online. Otherwise, the peer is considered offline.
  ///
  /// The [peerId] parameter specifies the ID of the peer to ping.
  ///
  /// Returns `true` if the peer is online, `false` otherwise.
  Future<bool> pingPeer(PeerId peerId) async {
    // If the peer is the same as the self ID, return true.
    if (peerId == selfId) {
      return true;
    }

    // Try to send a message to the peer.
    try {
      // Send a confirmable message to the peer and wait for an
      // acknowledgement.
      await sendMessage(isConfirmable: true, dstPeerId: peerId);

      // If the message was sent successfully, update the last seen
      // controller to indicate that the peer is online.
      _lastSeenController.add((peerId: peerId, isOnline: true));

      // Return true to indicate that the peer is online.
      return true;
    } on Object catch (_) {
      // Ignore any errors that occur during message sending.
    }

    // If the message was not sent successfully, update the last seen
    // controller to indicate that the peer is offline.
    _lastSeenController.add((
      peerId: peerId,
      isOnline: getPeerStatus(peerId),
    ));

    // Return false to indicate that the peer is offline.
    return false;
  }
}
