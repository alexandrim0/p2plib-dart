part of 'router.dart';

class P2PRouterL1 extends P2PRouterL0 {
  final _messageController = StreamController<P2PMessage>();
  final _ackCompleters = <int, Completer<int>>{};
  final _recieved = <P2PPacketHeader>{}; // TBD: remove, use P2PRoute?

  var retryPeriod = P2PRouterBase.defaultPeriod;

  Iterable<P2PFullAddress> get selfAddresses =>
      transports.map((t) => t.fullAddress);

  Stream<P2PMessage> get messageStream => _messageController.stream;

  P2PRouterL1({super.crypto, super.transports, super.logger});

  @override
  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    final cryptoKeys = await super.init(keys);
    // clear recieved headers
    Timer.periodic(
      retryPeriod,
      (_) {
        if (isNotRun) return;
        if (_recieved.isEmpty) return;
        final staleAt =
            DateTime.now().subtract(requestTimeout).millisecondsSinceEpoch;
        _recieved.removeWhere((header) => header.issuedAt < staleAt);
      },
    );
    return cryptoKeys;
  }

  @override
  void stop() {
    _ackCompleters.clear();
    super.stop();
  }

  /// returns null if message is processed and children have to return
  @override
  Future<P2PPacket?> onMessage(final P2PPacket packet) async {
    // exit if parent done all needed work
    if (await super.onMessage(packet) == null) return null;
    // drop duplicate
    if (_recieved.contains(packet.header)) return null;
    // remember to prevent duplicates processing
    _recieved.add(packet.header);
    // check and remove signature, decrypt if not empty
    final message = await crypto.unseal(packet.datagram, packet.header);
    // exit if message is ack for mine message
    if (_processAck(message, packet.srcFullAddress)) return null;
    // drop empty messages (keepalive)
    if (message.isEmpty) return null;
    // message is for user, send it to subscriber
    if (_messageController.hasListener) _messageController.add(message);
    return packet;
  }

  Future<P2PPacketHeader> sendMessage({
    final bool isConfirmable = false,
    required final P2PPeerId dstPeerId,
    final int? messageId,
    final Uint8List? payload,
    final Duration? ackTimeout,
  }) async {
    if (isNotRun) throw Exception('P2PRouter is not running!');

    final addresses = resolvePeerId(dstPeerId);
    if (addresses.isEmpty) throw Exception('Unknown route to $dstPeerId. ');

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
      logger?.call('sent ${datagram.length} bytes to $addresses');
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
        throw TimeoutException('Ack timeout');
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
      logger?.call(
        'sent confirmable message, id: $messageId to $addresses',
      );
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
          .then(
            (datagram) => sendDatagram(
              addresses: [srcAddress],
              datagram: datagram,
            ),
          );
    }
    return false;
  }
}
