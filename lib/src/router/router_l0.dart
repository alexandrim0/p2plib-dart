part of 'router.dart';

/// Basic router implementation for relaying and forwarding datagrams.
///
/// This class provides a lightweight and efficient implementation of a network
/// router, focusing on fast datagram relay and forwarding. It serves as a
/// foundation for more advanced router implementations with additional
/// features.
class RouterL0 extends RouterBase {
  RouterL0({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  }) {
    // Initializes the routes cleaner timer. Accessing `isActive` starts the
    // timer.
    _routesCleaner.isActive;
  }

  /// Defines the required clock synchronization accuracy between nodes, in
  /// milliseconds.
  ///
  /// This value represents the maximum acceptable difference in time between
  /// two nodes for them to be considered synchronized.
  int deltaT = const Duration(seconds: 10).inMilliseconds;

  /// Defines the maximum number of times a message can be forwarded.
  ///
  /// This value limits the potential for message loops and excessive network
  /// traffic by preventing messages from being forwarded indefinitely.
  int maxForwardsLimit = 1;

  /// A timer that periodically cleans stale routes from the routing table.
  ///
  /// This timer helps to ensure that the router maintains an accurate view of
  /// the network topology by removing routes to peers that have become
  /// unreachable.
  late final _routesCleaner = Timer.periodic(
    keepalivePeriod,
    (_) {
      if (routes.isNotEmpty) {
        final staleAt = _now - peerAddressTTL.inMilliseconds;

        routes
          ..forEach((_, r) => r.removeStaleAddresses(staleAt: staleAt))
          ..removeWhere((_, r) => r.isEmpty);
      }
    },
  );

  /// Handles incoming messages.
  ///
  /// [packet] The incoming [Packet] to be processed.
  ///
  /// This method is called by the transports when a new message is received.
  /// It is responsible for validating the message, updating routing information
  /// and potentially forwarding the message to other peers.
  ///
  /// Throws a [StopProcessing] exception if the message is invalid or has
  /// already been processed, or if an error occurs during processing.
  @override
  Future<Packet> onMessage(Packet packet) async {
    // Check if the datagram has the minimum required length.
    if (!Message.hasCorrectLength(packet.datagram)) {
      // If the datagram is too short, it's likely malformed. Stop processing.
      throw const StopProcessing();
    }

    // Check if the message timestamp is within the allowed deltaT.
    if (packet.header.issuedAt < _now - deltaT ||
        packet.header.issuedAt > _now + deltaT) {
      // If the timestamp is outside the acceptable range, it might be an old
      // or invalid message. Stop processing to prevent replay attacks.
      throw const ExceptionInvalidTimestamp();
    }

    // Extract the source peer ID from the datagram.
    packet.srcPeerId = Message.getSrcPeerId(packet.datagram);

    // Drop the packet if it is an echo message (sent by this peer).
    if (packet.srcPeerId == _selfId) {
      // Prevent processing messages sent by this router to avoid loops.
      throw const StopProcessing();
    }

    // Get the route associated with the source peer ID.
    final route = routes[packet.srcPeerId];

    // Drop the packet if it is a duplicate (already processed).
    if (route != null &&
        Route.maxStoredHeaders > 0 &&
        route.lastHeaders.contains(packet.header)) {
      // If the header has already been seen, the message is likely a
      // duplicate. Stop processing to prevent redundant handling.
      throw const StopProcessing();
    }

    // Reset the forwards count in the packet header for signature verification.
    PacketHeader.setForwardsCount(0, packet.datagram);

    // If the peer is unknown, verify the signature
    // and store the address if successful.
    if (route?.addresses[packet.srcFullAddress] == null) {
      try {
        // Verify the signature of the datagram to ensure its authenticity.
        await crypto.verify(packet.datagram);
      } on ExceptionInvalidSignature {
        // If the signature is invalid, the message is likely tampered with.
        // Stop processing to prevent potential security risks.
        throw const StopProcessing();
      }

      // Create a new route for the peer and store it in the routing table.
      routes[packet.srcPeerId] = Route(
        header: packet.header,
        peerId: packet.srcPeerId,
        address: (ip: packet.srcFullAddress, properties: AddressProperties()),
      );

      _log('Keep ${packet.srcFullAddress} for ${packet.srcPeerId}');
    } else {
      // If the peer is known, update the last seen timestamp and add the
      // header to the route's history.
      routes[packet.srcPeerId]!
        ..addresses[packet.srcFullAddress]?.updateLastSeen()
        ..addHeader(packet.header);

      _log(
        'Update lastseen of ${packet.srcFullAddress} for ${packet.srcPeerId}',
      );
    }
    // Extract the destination peer ID from the datagram.
    packet.dstPeerId = Message.getDstPeerId(packet.datagram);

    // If the message is for this peer, return it.
    if (packet.dstPeerId == _selfId) {
      // The message is intended for this router, so we return it for further
      // processing by higher-level layers.
      return packet;
    }

    // Check if the forwards count exceeds the maximum limit.
    if (packet.header.forwardsCount >= maxForwardsLimit) {
      // If the message has been forwarded too many times, it's likely stuck
      // in a loop. Stop processing to prevent infinite forwarding.
      throw const StopProcessing();
    }

    // Resolve the destination peer's addresses, excluding the source address
    // to prevent echo.
    final addresses = resolvePeerId(
      packet.dstPeerId,
    ).where((e) => e != packet.srcFullAddress);

    // If no route to the destination peer is found, log an error.
    if (addresses.isEmpty) {
      // If we cannot find a route to the destination, it means the peer is
      // currently unreachable. Log an error to indicate the routing failure.
      _log(
        'Unknown route to ${packet.dstPeerId}. '
        'Failed forwarding from ${packet.srcFullAddress}',
      );
    } else {
      // Increment the forwards count and forward the message to the resolved
      // addresses.
      sendDatagram(
        addresses: addresses,
        datagram: PacketHeader.setForwardsCount(
          packet.header.forwardsCount + 1,
          packet.datagram,
        ),
      );
      // Log the forwarding event, including the source and destination
      // addresses and the size of the datagram.
      _log(
        'forwarded from ${packet.srcFullAddress} '
        'to $addresses ${packet.datagram.length} bytes',
      );
    }

    // Stop processing the packet after forwarding or failing to forward.
    // For RouterL0, which acts primarily as a relay, further processing is
    // not necessary. This prevents the message from being handled by higher-
    // level routers or application logic.
    throw const StopProcessing();
  }
}
