part of 'router.dart';

/// This layer should be fast as possible and can be used as relay only node.
/// It can recieve, send and forward datagrams

class P2PRouterL0 extends P2PRouterBase {
  P2PRouterL0({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.logger,
  });

  @override
  Future<P2PCryptoKeys> init([final P2PCryptoKeys? keys]) async {
    final cryptoKeys = await super.init(keys);
    // remove stale records
    Timer.periodic(
      keepalivePeriod,
      (_) {
        if (isNotRun || routes.isEmpty) return;
        routes.forEach((_, r) => r.removeStaleAddresses(
              staleAt: _now - peerAddressTTL.inMilliseconds,
              preserveLocal: preserveLocalAddress,
            ));
        final routesCount = routes.length;
        routes.removeWhere((_, r) => r.isEmpty);
        final removedCount = routesCount - routes.length;
        if (removedCount > 0) _log('remove $removedCount empty routes');
      },
    );
    return cryptoKeys;
  }

  /// returns null if message is processed and children have to return
  @override
  Future<P2PPacket?> onMessage(final P2PPacket packet) async {
    // check minimal datagram length
    if (packet.datagram.length < P2PMessage.minimalLength) return null;

    final now = _now;
    // check if message is stale
    final delta = requestTimeout.inMilliseconds;
    if (packet.header.issuedAt < now - delta ||
        packet.header.issuedAt > now + delta) return null;

    packet.srcPeerId = P2PMessage.getSrcPeerId(packet.datagram);
    // drop echo message
    if (packet.srcPeerId == _selfId) return null;

    final route = routes[packet.srcPeerId];
    if (maxStoredHeaders > 0) {
      // drop duplicate
      if (route?.lastPacketHeader == packet.header) return null;
      // remember header to prevent duplicates processing
      routes[packet.srcPeerId]?.lastPacketHeader = packet.header;
    }

    // if peer unknown then check signature and keep address if success
    if (route?.addresses[packet.srcFullAddress] == null) {
      try {
        await crypto.openSigned(
          packet.srcPeerId!.signPiblicKey,
          // reset for checking signature
          P2PPacketHeader.setForwardsCount(0, packet.datagram),
        );
        routes[packet.srcPeerId!] = P2PRoute(
          peerId: packet.srcPeerId!,
          addresses: {packet.srcFullAddress: now},
        );
        _log('Keep ${packet.srcFullAddress} for ${packet.srcPeerId}');
      } catch (e) {
        _log(e.toString());
        return null; // exit on wrong signature
      }
    } else {
      // update peer address timestamp
      routes[packet.srcPeerId]!.addresses[packet.srcFullAddress] = now;
      _log(
        'Update lastseen of ${packet.srcFullAddress} for ${packet.srcPeerId!}',
      );
    }

    // is message for me or to forward?
    packet.dstPeerId = P2PMessage.getDstPeerId(packet.datagram);
    if (packet.dstPeerId == _selfId) return packet;

    // check if forwards count exeeds
    if (packet.header.forwardsCount >= maxForwardsCount) return null;

    // resolve peer address exclude source address to prevent echo
    final addresses = resolvePeerId(packet.dstPeerId!)
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
        datagram: P2PPacketHeader.setForwardsCount(
          packet.header.forwardsCount + 1,
          packet.datagram,
        ),
      );
      _log(
        'forwarded from ${packet.srcFullAddress} '
        'to $addresses ${packet.datagram.length} bytes',
      );
    }
    return null;
  }
}
