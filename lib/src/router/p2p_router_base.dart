part of 'router.dart';

class P2PRouterBase with P2PResolveHandler {
  static const defaultTimeout = Duration(seconds: 2);

  late final P2PPeerId selfId;
  final P2PCrypto crypto;
  final Iterable<P2PTransport> transports;
  final int defaultPort;
  final String? debugLabel;

  var maxForwardsCount = 1;
  var requestTimeout = defaultTimeout;
  void Function(String)? logger;

  var _isRun = false;

  bool get isRun => _isRun;
  bool get isNotRun => !_isRun;

  P2PRouterBase({
    final P2PCrypto? crypto,
    final Iterable<P2PTransport>? transports,
    this.defaultPort = 2022,
    this.debugLabel,
    this.logger,
  })  : crypto = crypto ?? P2PCrypto(),
        transports = transports ??
            [
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv4,
                port: defaultPort,
              )),
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv6,
                port: defaultPort,
              )),
            ];

  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    final cryptoKeys = await crypto.init(keys);
    selfId = P2PPeerId.fromKeys(
      encryptionKey: cryptoKeys.encPublicKey,
      signKey: cryptoKeys.signPublicKey,
    );
    return cryptoKeys;
  }

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
    // check minimal datagram length
    if (packet.datagram.length < P2PMessage.minimalLength) return null;
    // check if message is stale
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleAt = now - requestTimeout.inMilliseconds;
    if (packet.header.issuedAt < staleAt) return null;
    // drop echo message
    final srcPeerId = P2PMessage.getSrcPeerId(packet.datagram);
    if (srcPeerId == selfId) return null;
    // remember forwards count
    final forwardsCount = P2PPacketHeader.resetForwardsCount(packet.datagram);
    // if peer unknown then check signature and keep address if success
    if (_resolveCache[srcPeerId]?[packet.header.srcFullAddress] == null) {
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
    } else {
      // update peer address timestamp
      _resolveCache[srcPeerId]?[packet.header.srcFullAddress!] = now;
    }
    // is message for me or to forward?
    final dstPeerId = P2PMessage.getDstPeerId(packet.datagram);
    if (dstPeerId == selfId) return packet;
    // check if forwards count exeeds
    if (forwardsCount >= maxForwardsCount) return null;
    // resolve peer address exclude source address to prevent echo
    final addresses = resolvePeerId(dstPeerId)
        .where((e) => e != packet.header.srcFullAddress);
    if (addresses.isEmpty) {
      logger?.call(
        '[$debugLabel] Unknown route to $dstPeerId. '
        'Failed forwarding from ${packet.header.srcFullAddress}',
      );
    } else {
      // increment forwards count and forward message
      P2PPacketHeader.setForwardsCount(forwardsCount + 1, packet.datagram);
      sendDatagram(addresses: addresses, datagram: packet.datagram);
      logger?.call(
        '[$debugLabel] forwarded from ${packet.header.srcFullAddress} '
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

  Future<P2PPacketHeader> sendMessage({
    final bool isConfirmable = false,
    required final P2PPeerId dstPeerId,
    final int? messageId,
    final Uint8List? payload,
    final Duration? ackTimeout,
  }) =>
      throw Exception('Must be implemented in children');
}
