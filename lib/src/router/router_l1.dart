part of 'router.dart';

/// This layer do enhanced protocol features like confirmation and keepalive.
/// It can send and process messages, so can be used as advanced relay node.
/// Also it can be an base class for poor client.

class RouterL1 extends RouterL0 {
  var retryPeriod = const Duration(seconds: 1);

  final _ackCompleters = <int, Completer<void>>{};
  final _messageController = StreamController<Message>();

  RouterL1({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  });

  Iterable<FullAddress> get selfAddresses =>
      transports.map((t) => t.bindAddress);

  Stream<Message> get messageStream => _messageController.stream;

  @override
  Future<CryptoKeys> init([CryptoKeys? keys]) async {
    final cryptoKeys = await super.init(keys);

    // send keepalive messages
    Timer.periodic(
      keepalivePeriod,
      (_) {
        if (isNotRun || routes.isEmpty) return;
        for (final route in routes.values) {
          final addresses = route.addresses.entries
              .where((e) => e.value.isNotLocal)
              .map((e) => e.key);
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
      c.completeError(const ExceptionIsNotRunning());
    }
    _ackCompleters.clear();
    super.stop();
  }

  @override
  Future<Packet> onMessage(final Packet packet) async {
    await super.onMessage(packet);

    // check and remove signature, decrypt if not empty
    packet.payload = await crypto.unseal(packet.datagram);

    // exit if message is confirmation of mine message
    if (packet.header.messageType == PacketType.confirmation) {
      _ackCompleters.remove(packet.header.id)?.complete();
      throw const StopProcessing();
    }

    // send confirmation if required
    if (packet.header.messageType == PacketType.confirmable) {
      crypto
          .sign(Message(
            header: packet.header.copyWith(
              messageType: PacketType.confirmation,
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
      _messageController.add(Message(
        header: packet.header,
        srcPeerId: packet.srcPeerId,
        dstPeerId: packet.dstPeerId,
        payload: packet.payload,
      ));
    }

    return packet;
  }

  /// Send message. If useAddress is not null then use this else resolve peerId
  Future<PacketHeader> sendMessage({
    final bool isConfirmable = false,
    required final PeerId dstPeerId,
    final int? messageId,
    final Uint8List? payload,
    final Duration? ackTimeout,
    final Iterable<FullAddress>? useAddresses,
  }) async {
    if (isNotRun) throw const ExceptionIsNotRunning();

    final addresses = useAddresses ?? resolvePeerId(dstPeerId);
    if (addresses.isEmpty) throw ExceptionUnknownRoute(dstPeerId);

    final message = Message(
      header: PacketHeader(
        messageType:
            isConfirmable ? PacketType.confirmable : PacketType.regular,
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
    required final Iterable<FullAddress> addresses,
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
        .timeout(ackTimeout ?? messageTTL)
        .whenComplete(() => _ackCompleters.remove(messageId));
  }

  void _sendAndRetry({
    required final int messageId,
    required final Uint8List datagram,
    required final Iterable<FullAddress> addresses,
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
