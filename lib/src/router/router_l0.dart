part of 'router.dart';

/// This layer should be fast as possible and can be used as relay only node.
/// It can recieve, send and forward datagrams

class RouterL0 extends RouterBase {
  /// Defines required clock sync accuracy between nodes
  var deltaT = const Duration(seconds: 10).inMilliseconds;

  /// Defines how much times message can be forwarded
  var maxForwardsLimit = 1;

  RouterL0({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  });

  @override
  Future<Uint8List> init([Uint8List? seed]) async {
    final cryptoKeys = await super.init(seed);
    // remove stale records
    Timer.periodic(
      keepalivePeriod,
      (_) {
        if (isNotRun || routes.isEmpty) return;
        routes.forEach((_, r) => r.removeStaleAddresses(
              staleAt: _now - peerAddressTTL.inMilliseconds,
            ));
        final routesCount = routes.length;
        routes.removeWhere((_, r) => r.isEmpty);
        final removedCount = routesCount - routes.length;
        if (removedCount > 0) _log('remove $removedCount empty routes');
      },
    );
    return cryptoKeys;
  }

  @override
  Future<Packet> onMessage(final Packet packet) async {
    // check minimal datagram length
    if (!Message.hasCorrectLength(packet.datagram)) {
      throw const StopProcessing();
    }

    // check if message is in deltaT
    if (packet.header.issuedAt < _now - deltaT ||
        packet.header.issuedAt > _now + deltaT) {
      throw const ExceptionInvalidTimestamp();
    }

    packet.srcPeerId = Message.getSrcPeerId(packet.datagram);

    // drop echo message
    if (packet.srcPeerId == _selfId) throw const StopProcessing();

    final route = routes[packet.srcPeerId];

    // drop duplicate
    if (route != null &&
        Route.maxStoredHeaders > 0 &&
        route.lastHeaders.contains(packet.header)) {
      throw const StopProcessing();
    }

    // reset for checking signature
    PacketHeader.setForwardsCount(0, packet.datagram);

    // if peer unknown then check signature and keep address if success
    if (route?.addresses[packet.srcFullAddress] == null) {
      try {
        await crypto.verify(packet.datagram);
      } on ExceptionInvalidSignature {
        throw const StopProcessing();
      }
      routes[packet.srcPeerId] = Route(
        header: packet.header,
        peerId: packet.srcPeerId,
        address: (ip: packet.srcFullAddress, properties: AddressProperties()),
      );
      _log('Keep ${packet.srcFullAddress} for ${packet.srcPeerId}');
    } else {
      routes[packet.srcPeerId]!
        // update peer address timestamp
        ..addresses[packet.srcFullAddress]?.updateLastSeen()
        // remember header to prevent duplicates processing
        ..addHeader(packet.header);
      _log(
        'Update lastseen of ${packet.srcFullAddress} for ${packet.srcPeerId}',
      );
    }

    packet.dstPeerId = Message.getDstPeerId(packet.datagram);

    // is message for me or to forward?
    if (packet.dstPeerId == _selfId) return packet;

    // check if forwards count exeeds
    if (packet.header.forwardsCount >= maxForwardsLimit) {
      throw const StopProcessing();
    }

    // resolve peer address exclude source address to prevent echo
    final addresses = resolvePeerId(packet.dstPeerId)
        .where((e) => e != packet.srcFullAddress);

    if (addresses.isEmpty) {
      _log(
        'Unknown route to ${packet.dstPeerId}. '
        'Failed forwarding from ${packet.srcFullAddress}',
      );
    } else {
      // increment forwards count and forward message
      sendDatagram(
        addresses: addresses,
        datagram: PacketHeader.setForwardsCount(
          packet.header.forwardsCount + 1,
          packet.datagram,
        ),
      );
      _log(
        'forwarded from ${packet.srcFullAddress} '
        'to $addresses ${packet.datagram.length} bytes',
      );
    }
    throw const StopProcessing();
  }
}
