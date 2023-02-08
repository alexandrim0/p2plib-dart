part of 'router.dart';

/// This layer do enhanced protocol features like confirmation and keepalive.
/// It can send and process messages, so can be used as advanced relay node.
/// Also it can be an base class for poor client.

class P2PRouterL1 extends P2PRouterL0 {
  var retryPeriod = P2PRouterBase.defaultPeriod;

  final _ackCompleters = <int, Completer<void>>{};
  final _messageController = StreamController<P2PMessage>();

  P2PRouterL1({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.logger,
  });

  Iterable<P2PFullAddress> get selfAddresses =>
      transports.map((t) => t.fullAddress);

  Stream<P2PMessage> get messageStream => _messageController.stream;

  @override
  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    final cryptoKeys = await super.init(keys);
    // send keepalive messages
    Timer.periodic(
      keepalivePeriod,
      (_) {
        if (isNotRun || routes.isEmpty) return;
        for (final route in routes.values) {
          final addresses = route.addresses.keys.where((a) => a.isNotLocal);
          if (addresses.isNotEmpty) {
            sendMessage(dstPeerId: route.peerId, useAddresses: addresses);
          }
        }
      },
    );
    return cryptoKeys;
  }

  @override
  void stop() {
    for (final c in _ackCompleters.values) {
      c.completeError(const P2PExceptionRouterIsNotRunning());
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
    packet.payload = await crypto.unseal(packet.datagram);

    // exit if message is confirmation of mine message
    if (packet.header.messageType == P2PPacketType.confirmation) {
      _ackCompleters.remove(packet.header.id)?.complete();
      return null;
    }

    // send confirmation if required
    if (packet.header.messageType == P2PPacketType.confirmable) {
      crypto
          .sign(P2PMessage(
            header: packet.header.copyWith(
              messageType: P2PPacketType.confirmation,
            ),
            srcPeerId: selfId,
            dstPeerId: packet.srcPeerId,
          ).toBytes())
          .then((datagram) => sendDatagram(
                addresses: [packet.srcFullAddress],
                datagram: datagram,
              ));
    }

    // message is for user, send it to subscriber
    if (packet.payload.isNotEmpty && _messageController.hasListener) {
      _messageController.add(P2PMessage(
        header: packet.header,
        srcPeerId: packet.srcPeerId,
        dstPeerId: packet.dstPeerId,
        payload: packet.payload,
      ));
    }

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

    final message = P2PMessage(
      header: P2PPacketHeader(
        messageType:
            isConfirmable ? P2PPacketType.confirmable : P2PPacketType.regular,
        issuedAt: _now,
        id: messageId ?? genRandomInt(),
      ),
      srcPeerId: selfId,
      dstPeerId: dstPeerId,
      payload: payload,
    );
    final datagram = await crypto.seal(message);

    if (isConfirmable) {
      await sendDatagramConfirmable(
        messageId: message.header.id,
        datagram: datagram,
        addresses: addresses,
        ackTimeout: ackTimeout,
      );
    } else {
      sendDatagram(addresses: addresses, datagram: datagram);
      _log('sent ${datagram.length} bytes to $addresses');
    }
    return message.header;
  }

  Future<void> sendDatagramConfirmable({
    required final int messageId,
    required final Uint8List datagram,
    required final Iterable<P2PFullAddress> addresses,
    final Duration? ackTimeout,
  }) {
    final completer = Completer<void>();
    _ackCompleters[messageId] = completer;
    _sendAndRetry(
      datagram: datagram,
      messageId: messageId,
      addresses: addresses,
    );
    return completer.future
        .timeout(ackTimeout ?? requestTimeout)
        .whenComplete(() => _ackCompleters.remove(messageId));
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
}
