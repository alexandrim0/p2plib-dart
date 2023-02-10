part of 'router.dart';

/// This layer should be fast as possible and can be used as relay only node.
/// It can recieve, send and forward datagrams

class RouterL0 extends RouterBase {
  RouterL0({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.logger,
  });

  @override
  Future<CryptoKeys> init([final CryptoKeys? keys]) async {
    final cryptoKeys = await super.init(keys);
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

    final now = _now;
    // check if message is stale
    final delta = requestTimeout.inMilliseconds;
    if (packet.header.issuedAt < now - delta ||
        packet.header.issuedAt > now + delta) throw const StopProcessing();

    packet.srcPeerId = Message.getSrcPeerId(packet.datagram);
    // drop echo message
    if (packet.srcPeerId == _selfId) throw const StopProcessing();

    final route = routes[packet.srcPeerId];

    // drop duplicate
    if (route != null &&
        Route.maxStoredHeaders > 0 &&
        route.lastHeaders.contains(packet.header)) throw const StopProcessing();

    // reset for checking signature
    PacketHeader.setForwardsCount(0, packet.datagram);

    // if peer unknown then check signature and keep address if success
    if (route?.addresses[packet.srcFullAddress] == null) {
      if (await crypto.verifySigned(
        packet.srcPeerId.signPiblicKey,
        packet.datagram,
      )) {
        routes[packet.srcPeerId] = Route(
          header: packet.header,
          peerId: packet.srcPeerId,
          address: MapEntry(packet.srcFullAddress, now),
        );
        _log('Keep ${packet.srcFullAddress} for ${packet.srcPeerId}');
      } else {
        // exit on wrong signature
        throw const StopProcessing();
      }
    } else {
      routes[packet.srcPeerId]!
        // update peer address timestamp
        ..addresses[packet.srcFullAddress] = now
        // remember header to prevent duplicates processing
        ..addHeader(packet.header);
      _log(
        'Update lastseen of ${packet.srcFullAddress} for ${packet.srcPeerId}',
      );
    }

    // is message for me or to forward?
    packet.dstPeerId = Message.getDstPeerId(packet.datagram);
    if (packet.dstPeerId == _selfId) return packet;

    // check if forwards count exeeds
    if (packet.header.forwardsCount >= maxForwardsCount) {
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
