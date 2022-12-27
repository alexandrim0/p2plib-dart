part of 'router.dart';

mixin P2PHandlerAck on P2PRouterBase {
  final _completers = <int, Completer<void>>{};

  var ackTimeout = P2PRouterBase.defaultTimeout;
  var ackRetryPeriod = P2PRouterBase.defaultPeriod;

  void _stopAckHandler() {
    _completers.clear();
  }

  /// returns true if message is processed
  bool _processAck(final P2PMessage message) {
    if (message.header.messageType == P2PPacketType.acknowledgement) {
      _completers.remove(message.header.id)?.complete();
      return true;
    }
    if (message.header.messageType == P2PPacketType.confirmable) {
      crypto
          .sign(P2PMessage(
            header: message.header.copyWith(
              messageType: P2PPacketType.acknowledgement,
            ),
            srcPeerId: selfId,
            dstPeerId: message.srcPeerId,
          ).toBytes())
          .then(
            (datagram) => sendDatagram(
              addresses: [message.header.srcFullAddress!],
              datagram: datagram,
            ),
          );
    }
    return false;
  }

  Future<void> _ackBack({
    required final int messageId,
    required final Uint8List datagram,
    required final Iterable<P2PFullAddress> addresses,
    required final Duration timeout,
  }) {
    final completer = Completer<void>();
    _completers[messageId] = completer;
    _sendAgain(datagram: datagram, messageId: messageId, addresses: addresses);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (_completers.remove(messageId) == null) return;
        throw TimeoutException('[$debugLabel] Ack timeout');
      },
    );
  }

  void _sendAgain({
    required final int messageId,
    required final Uint8List datagram,
    required final Iterable<P2PFullAddress> addresses,
  }) async {
    await Future.delayed(ackRetryPeriod);
    if (isNotRun) return;
    if (!_completers.containsKey(messageId)) return;
    sendDatagram(addresses: addresses, datagram: datagram);
    _sendAgain(datagram: datagram, messageId: messageId, addresses: addresses);
  }
}
