part of 'router.dart';

class P2PRouter extends P2PRouterBase with P2PHandlerAck, P2PHandlerLastSeen {
  final _messageController = StreamController<P2PMessage>();
  final Set<P2PPacketHeader> _recieved = {};

  Iterable<P2PFullAddress> get selfAddresses =>
      transports.map((t) => t.fullAddress);

  Stream<P2PMessage> get messageStream => _messageController.stream;

  Stream<MapEntry<P2PPeerId, bool>> get lastSeenStream =>
      _lastSeenController.stream;

  P2PRouter({
    super.crypto,
    super.transports,
    super.debugLabel,
    super.logger,
  }) {
    // clear recieved headers
    Timer.periodic(
      requestTimeout,
      (_) {
        if (_recieved.isEmpty) return;
        final staleAt =
            DateTime.now().subtract(requestTimeout).millisecondsSinceEpoch;
        _recieved.removeWhere((header) => header.issuedAt < staleAt);
      },
    );
  }

  @override
  void stop() {
    _stopAckHandler();
    _stopLastSeenHandler();
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
    _processLastSeen(message);
    // exit if message is ack for mine message
    if (_processAck(message)) return null;
    // message is for user, send it to subscriber
    if (_messageController.hasListener) _messageController.add(message);
    return packet;
  }

  Future<int> sendMessage({
    final bool isConfirmable = false,
    required final P2PPeerId dstPeerId,
    final int? messageId,
    final Uint8List? payload,
    final Duration? ackTimeout,
  }) async {
    if (isNotRun) throw Exception('[$debugLabel] P2PRouter is not running!');
    final addresses = resolvePeerId(dstPeerId);
    final message = P2PMessage(
      header: P2PPacketHeader(
        protocolNumber: P2PMessage.protocolNumber,
        messageType:
            isConfirmable ? P2PPacketType.confirmable : P2PPacketType.regular,
        id: messageId ?? genRandomInt(),
      ),
      srcPeerId: selfId,
      dstPeerId: dstPeerId,
      payload: payload,
    );
    final datagram = await crypto.seal(message);
    sendDatagram(addresses: addresses, datagram: datagram);

    if (isConfirmable) {
      await _ackBack(
        messageId: message.header.id,
        datagram: datagram,
        addresses: addresses,
        timeout: ackTimeout ?? this.ackTimeout,
      );
    }
    return message.header.id;
  }

  @override
  Future<void> _sendEmptyConfirmableTo(final P2PPeerId dstPeerId) =>
      sendMessage(
        isConfirmable: true,
        dstPeerId: dstPeerId,
        ackTimeout: ackTimeout,
      );
}
