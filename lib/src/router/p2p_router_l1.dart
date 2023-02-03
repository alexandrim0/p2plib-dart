part of 'router.dart';

/// This layer do enhanced protocol features like ack, dedup and keepalive
/// It can send and process messages, so can be used as advanced relay node
class P2PRouterL1 extends P2PRouterL0 {
  final _ackCompleters = <int, Completer<int>>{};

  var retryPeriod = P2PRouterBase.defaultPeriod;

  Iterable<P2PFullAddress> get selfAddresses =>
      transports.map((t) => t.fullAddress);

  P2PRouterL1({super.crypto, super.transports, super.logger});

  @override
  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    final cryptoKeys = await super.init(keys);
    // send keepalive messages
    Timer.periodic(
      keepalivePeriod,
      (_) {
        if (isNotRun) return;
        if (routes.isEmpty) return;
        for (final route in routes.values) {
          final addresses = route.addresses.keys.where((a) => a.isNotLocal);
          if (addresses.isEmpty) continue;
          sendMessage(dstPeerId: route.peerId, useAddresses: addresses);
        }
      },
    );
    return cryptoKeys;
  }

  @override
  void stop() {
    for (final c in _ackCompleters.values) {
      c.complete(0);
    }
    _ackCompleters.clear();
    super.stop();
  }

  /// returns null if message is processed and children have to return
  @override
  Future<P2PPacket?> onMessage(final P2PPacket packet) async {
    // exit if parent done all needed work
    if (await super.onMessage(packet) == null) return null;
    // check and remove signature, decrypt if not empty
    packet.message = await crypto.unseal(packet.datagram);
    // exit if message is ack for mine message
    if (_processAck(packet.message!, packet.srcFullAddress)) return null;
    return packet;
  }

  /// Send message. If useAddress is not null then use this else resolve peerId
  Future<P2PPacketHeader> sendMessage({
    final bool isConfirmable = false,
    required final P2PPeerId dstPeerId,
    final int? messageId,
    final Uint8List? payload,
    final Duration? ackTimeout,
    final Iterable<P2PFullAddress>? useAddresses,
  }) async {
    if (isNotRun) throw const P2PExceptionRouterIsNotRunning();

    final addresses = useAddresses ?? resolvePeerId(dstPeerId);
    if (addresses.isEmpty) {
      throw P2PExceptionRouterUnknownRoute(dstPeerId);
    }

    final header = P2PPacketHeader(
      messageType:
          isConfirmable ? P2PPacketType.confirmable : P2PPacketType.regular,
      id: messageId ?? genRandomInt(),
    );
    final datagram = await crypto.seal(P2PMessage(
      header: header,
      srcPeerId: selfId,
      dstPeerId: dstPeerId,
      payload: payload,
    ));

    if (isConfirmable) {
      await sendDatagramConfirmable(
        messageId: header.id,
        datagram: datagram,
        addresses: addresses,
        ackTimeout: ackTimeout,
      );
    } else {
      sendDatagram(addresses: addresses, datagram: datagram);
      _log('sent ${datagram.length} bytes to $addresses');
    }
    return header;
  }

  // TBD: make as Future<void>
  Future<int> sendDatagramConfirmable({
    required final int messageId,
    required final Uint8List datagram,
    required final Iterable<P2PFullAddress> addresses,
    final Duration? ackTimeout,
  }) {
    final completer = Completer<int>();
    _ackCompleters[messageId] = completer;
    _sendAndRetry(
      datagram: datagram,
      messageId: messageId,
      addresses: addresses,
    );
    return completer.future.timeout(
      ackTimeout ?? requestTimeout,
      onTimeout: () {
        if (_ackCompleters.remove(messageId) == null) return messageId;
        throw TimeoutException('Confirmation timeout');
      },
    );
  }

  void _sendAndRetry({
    required final int messageId,
    required final Uint8List datagram,
    required final Iterable<P2PFullAddress> addresses,
  }) {
    if (isRun && _ackCompleters.containsKey(messageId)) {
      sendDatagram(addresses: addresses, datagram: datagram);
      _log('sent confirmable message, id: $messageId to $addresses');
      Future.delayed(
        retryPeriod,
        () => _sendAndRetry(
          datagram: datagram,
          messageId: messageId,
          addresses: addresses,
        ),
      );
    }
  }

  /// returns true if message is processed
  bool _processAck(final P2PMessage message, final P2PFullAddress srcAddress) {
    if (message.header.messageType == P2PPacketType.confirmation) {
      _ackCompleters
          .remove(message.header.id)
          ?.complete(message.payload.length);
      return true;
    }
    if (message.header.messageType == P2PPacketType.confirmable) {
      crypto
          .sign(P2PMessage(
            header: message.header.copyWith(
              messageType: P2PPacketType.confirmation,
            ),
            srcPeerId: selfId,
            dstPeerId: message.srcPeerId,
          ).toBytes())
          .then((d) => sendDatagram(addresses: [srcAddress], datagram: d));
    }
    return false;
  }
}
