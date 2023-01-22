part of 'router.dart';

class P2PRouterL0 {
  static const defaultPort = 2022;
  static const defaultTimeout = Duration(seconds: 3);

  final Map<P2PPeerId, P2PRoute> routes = {};
  final Iterable<P2PTransport> transports;
  final P2PCrypto crypto;

  var peerAddressTTL = const Duration(seconds: 30);
  var requestTimeout = defaultTimeout;
  var useForwardersCount = 2;
  var maxForwardsCount = 1;
  void Function(String)? logger;

  late final P2PPeerId _selfId;
  var _isRun = false;

  bool get isRun => _isRun;
  bool get isNotRun => !_isRun;
  P2PPeerId get selfId => _selfId;

  P2PRouterL0({
    final P2PCrypto? crypto,
    final Iterable<P2PTransport>? transports,
    this.logger,
  })  : crypto = crypto ?? P2PCrypto(),
        transports = transports ??
            [
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv4,
                isLocal: false,
                port: defaultPort,
              )),
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv6,
                isLocal: false,
                port: defaultPort,
              )),
            ];

  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    final cryptoKeys = await crypto.init(keys);
    _selfId = P2PPeerId.fromKeys(
      encryptionKey: cryptoKeys.encPublicKey,
      signKey: cryptoKeys.signPublicKey,
    );
    return cryptoKeys;
  }

  Future<void> start() async {
    if (_isRun) return;
    logger?.call('Start listen $transports with key $_selfId');
    if (transports.isEmpty) {
      throw Exception('Need at least one P2PTransport!');
    }
    for (final t in transports) {
      t.ttl = requestTimeout.inSeconds;
      t.callback = onMessage;
      await t.start();
    }
    _isRun = true;
  }

  void stop() {
    _isRun = false;
    for (final t in transports) {
      t.stop();
    }
  }

  /// returns null if message is processed and children have to return
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
    if (routes[srcPeerId]?.addresses[packet.header.srcFullAddress!] == null) {
      try {
        // Set forwards count to zero for checking signature
        P2PPacketHeader.resetForwardsCount(packet.datagram);
        await crypto.openSigned(srcPeerId.signPiblicKey, packet.datagram);
        routes[srcPeerId] = P2PRoute(
          peerId: srcPeerId,
          addresses: {packet.header.srcFullAddress!: now},
        );
        logger?.call('Keep ${packet.header.srcFullAddress} for $srcPeerId');
      } catch (e) {
        logger?.call(e.toString());
        return null; // exit on wrong signature
      }
    } else {
      // update peer address timestamp
      routes[srcPeerId]!.addresses[packet.header.srcFullAddress!] = now;
    }

    // is message for me or to forward?
    final dstPeerId = P2PMessage.getDstPeerId(packet.datagram);
    if (dstPeerId == _selfId) return packet;

    // check if forwards count exeeds
    if (packet.header.forwardsCount >= maxForwardsCount) return null;

    // resolve peer address exclude source address to prevent echo
    final addresses = resolvePeerId(dstPeerId)
        .where((e) => e != packet.header.srcFullAddress);
    if (addresses.isEmpty) {
      logger?.call(
        'Unknown route to $dstPeerId. '
        'Failed forwarding from ${packet.header.srcFullAddress}',
      );
    } else {
      // increment forwards count and forward message
      P2PPacketHeader.setForwardsCount(
        packet.header.forwardsCount + 1,
        packet.datagram,
      );
      sendDatagram(addresses: addresses, datagram: packet.datagram);
      logger?.call(
        'forwarded from ${packet.header.srcFullAddress} '
        'to $addresses ${packet.datagram.length} bytes',
      );
    }
    return null;
  }

  int sendDatagram({
    required final Iterable<P2PFullAddress> addresses,
    required final Uint8List datagram,
  }) {
    for (final t in transports) {
      t.send(addresses, datagram);
    }
    return datagram.length;
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
          staleBefore:
              DateTime.now().subtract(peerAddressTTL).millisecondsSinceEpoch);
    }
  }
}
