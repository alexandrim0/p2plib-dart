part of 'router.dart';

/// This layer should be fast as possible and can be used as relay only node.
/// It can recieve, send and forward datagrams
class P2PRouterL0 extends P2PRouterBase {
  var keepalivePeriod = P2PRouterBase.defaultAddressTTL ~/ 2;
  var peerAddressTTL = P2PRouterBase.defaultAddressTTL;
  var requestTimeout = P2PRouterBase.defaultTimeout;
  var preserveLocalAddress = false; // More efficient for relay node
  var useForwardersCount = 2;
  var maxForwardsCount = 1;

  P2PRouterL0({super.crypto, super.transports, super.logger});

  @override
  Future<P2PCryptoKeys> init([final P2PCryptoKeys? keys]) async {
    final cryptoKeys = await super.init(keys);
    // remove stale records
    Timer.periodic(
      keepalivePeriod,
      (_) {
        if (isNotRun) return;
        if (routes.isEmpty) return;
        final staleAt =
            DateTime.now().subtract(peerAddressTTL).millisecondsSinceEpoch;
        routes.forEach((_, r) => r.removeStaleAddresses(
              staleAt: staleAt,
              preserveLocal: preserveLocalAddress,
            ));
        routes.removeWhere((_, r) => r.isEmpty);
      },
    );
    return cryptoKeys;
  }

  /// returns null if message is processed and children have to return
  @override
  Future<P2PPacket?> onMessage(final P2PPacket packet) async {
    // check minimal datagram length
    if (packet.datagram.length < P2PMessage.minimalLength) return null;

    // check if message is stale
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleAt = now - requestTimeout.inMilliseconds;
    if (packet.header.issuedAt < staleAt) return null;

    // drop echo message
    final srcPeerId = P2PMessage.getSrcPeerId(packet.datagram);
    if (srcPeerId == _selfId) return null;

    // if peer unknown then check signature and keep address if success
    if (routes[srcPeerId]?.addresses[packet.srcFullAddress] == null) {
      try {
        // Set forwards count to zero for checking signature
        P2PPacketHeader.resetForwardsCount(packet.datagram);
        await crypto.openSigned(srcPeerId.signPiblicKey, packet.datagram);
        routes[srcPeerId] = P2PRoute(
          peerId: srcPeerId,
          addresses: {packet.srcFullAddress: now},
        );
        logger?.call('Keep ${packet.srcFullAddress} for $srcPeerId');
      } catch (e) {
        logger?.call(e.toString());
        return null; // exit on wrong signature
      }
    } else {
      // update peer address timestamp
      routes[srcPeerId]!.addresses[packet.srcFullAddress] = now;
    }

    // is message for me or to forward?
    final dstPeerId = P2PMessage.getDstPeerId(packet.datagram);
    if (dstPeerId == _selfId) return packet;

    // check if forwards count exeeds
    if (packet.header.forwardsCount >= maxForwardsCount) return null;

    // resolve peer address exclude source address to prevent echo
    final addresses =
        resolvePeerId(dstPeerId).where((e) => e != packet.srcFullAddress);
    if (addresses.isEmpty) {
      logger?.call(
        'Unknown route to $dstPeerId. '
        'Failed forwarding from ${packet.srcFullAddress}',
      );
    } else {
      // increment forwards count and forward message
      P2PPacketHeader.setForwardsCount(
        packet.header.forwardsCount + 1,
        packet.datagram,
      );
      sendDatagram(addresses: addresses, datagram: packet.datagram);
      logger?.call(
        'forwarded from ${packet.srcFullAddress} '
        'to $addresses ${packet.datagram.length} bytes',
      );
    }
    return null;
  }

  /// Returns cached addresses or who can forward
  Iterable<P2PFullAddress> resolvePeerId(final P2PPeerId peerId) {
    final route = routes[peerId];
    if (route == null || route.isEmpty) {
      final result = <P2PFullAddress>{};
      for (final a in routes.values.where((e) => e.canForward)) {
        result.addAll(a.addresses.keys);
      }
      return result.take(useForwardersCount);
    } else {
      return route.getActualAddresses(
        staleAt: DateTime.now().subtract(peerAddressTTL).millisecondsSinceEpoch,
        preserveLocal: preserveLocalAddress,
      );
    }
  }
}
