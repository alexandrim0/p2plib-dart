part of 'router.dart';

class P2PRouterBase with P2PResolveHandler {
  static const defaultTimeout = Duration(seconds: 3);
  static const defaultPeriod = Duration(seconds: 1);

  final P2PPeerId selfId;
  final P2PCrypto crypto;
  final Iterable<P2PTransport> transports;
  final String? debugLabel;

  var forwardFromKnownPeerOnly = false;
  var requestTimeout = defaultTimeout;
  void Function(String)? logger;

  var _isRun = false;

  bool get isRun => _isRun;
  bool get isNotRun => !_isRun;

  P2PRouterBase({
    required this.crypto,
    required this.transports,
    this.debugLabel,
    this.logger,
  }) : selfId = P2PPeerId.fromKeys(
          encryptionKey: crypto.cryptoKeys.encPublicKey,
          signKey: crypto.cryptoKeys.signPublicKey,
        );

  Future<void> start() async {
    if (_isRun) return;
    logger?.call('[$debugLabel] Start listen $transports with key $selfId');
    if (transports.isEmpty) {
      throw Exception('[$debugLabel] Need at least one P2PTransport!');
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
    // check minimal datagram length (for protocol number 0 for now)
    if (packet.datagram.length < P2PMessage.minimalLength) return null;
    // check if message is stale
    final staleAt =
        DateTime.now().subtract(requestTimeout).millisecondsSinceEpoch;
    if (packet.header.issuedAt < staleAt) return null;
    // drop echo message
    final srcPeerId = P2PMessage.getSrcPeerId(packet.datagram);
    if (srcPeerId == selfId) return null;
    // if peer unknown then check signature and keep address if success
    if (_cache[srcPeerId]?[packet.header.srcFullAddress] == null) {
      try {
        await crypto.openSigned(srcPeerId.signPiblicKey, packet.datagram);
        addPeerAddress(
          peerId: srcPeerId,
          addresses: [packet.header.srcFullAddress!],
        );
        logger?.call(
          '[$debugLabel] Keep ${packet.header.srcFullAddress} for $srcPeerId',
        );
      } catch (e) {
        logger?.call(e.toString());
        return null; // exit on wrong signature
      }
    }
    // is message for me or to forward?
    final dstPeerId = P2PMessage.getDstPeerId(packet.datagram);
    if (dstPeerId == selfId) return packet;
    // exit if forward for anonymous disabled
    if (forwardFromKnownPeerOnly && !_cache.containsKey(dstPeerId)) return null;
    // resolve peer address exclude source address to prevent echo
    final addresses = resolvePeerId(dstPeerId)
        .where((e) => e != packet.header.srcFullAddress);
    if (addresses.isEmpty) {
      logger?.call(
        '[$debugLabel] Unknown route to $dstPeerId. '
        'Failed forwarding from ${packet.header.srcFullAddress}',
      );
    } else {
      // forward message
      sendDatagram(addresses: addresses, datagram: packet.datagram);
      logger?.call(
        '[$debugLabel] forwarded from ${packet.header.srcFullAddress} '
        'to $addresses ${packet.datagram.length} bytes',
      );
    }
    return packet;
  }

  void sendDatagram({
    required final Iterable<P2PFullAddress> addresses,
    required final Uint8List datagram,
  }) {
    for (final t in transports) {
      t.send(addresses, datagram);
    }
  }
}
