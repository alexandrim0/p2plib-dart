part of 'router.dart';

mixin P2PHandlerAck on P2PRouterBase {
  final _ackCompleters = <int, Completer<void>>{};

  var ackTimeout = P2PRouterBase.defaultTimeout;
  var ackRetryPeriod = P2PRouterBase.defaultPeriod;

  void _stopAckHandler() {
    _ackCompleters.clear();
  }

  /// returns true if message is processed
  bool _processAck(final P2PMessage message) {
    if (message.header.messageType == P2PPacketType.confirmation) {
      _ackCompleters.remove(message.header.id)?.complete();
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
              addresses: [message.header.srcFullAddress!],
              datagram: datagram,
            ),
          );
    }
    return false;
  }

  Future<void> _sendDatagramRetry({
    required final int messageId,
    required final Uint8List datagram,
    required final Iterable<P2PFullAddress> addresses,
  }) {
    final completer = Completer<void>();
    _ackCompleters[messageId] = completer;
    _sendAndRetry(
      datagram: datagram,
      messageId: messageId,
      addresses: addresses,
    );
    return completer.future.timeout(
      ackTimeout,
      onTimeout: () {
        if (_ackCompleters.remove(messageId) == null) return;
        throw TimeoutException('[$debugLabel] Ack timeout');
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
      Future.delayed(
        ackRetryPeriod,
        () => _sendAndRetry(
          datagram: datagram,
          messageId: messageId,
          addresses: addresses,
        ),
      );
      logger?.call(
        '[$debugLabel] send confirmable message, id: $messageId'
        ' to $addresses',
      );
    }
  }
}
