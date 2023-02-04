part of 'transport.dart';

class P2PUdpTransport extends P2PTransportBase {
  RawDatagramSocket? _socket;

  P2PUdpTransport({required super.fullAddress, super.callback, super.ttl});

  @override
  Future<void> start() async {
    if (_socket != null) return;
    _socket = await RawDatagramSocket.bind(
      fullAddress.address,
      fullAddress.port,
      ttl: ttl,
    );
    _socket!.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket?.receive();
        if (datagram == null || datagram.data.length < P2PPacketHeader.length) {
          return;
        }
        try {
          callback!(P2PPacket(
            srcFullAddress: P2PFullAddress(
              address: datagram.address,
              isLocal: fullAddress.isLocal,
              port: datagram.port,
            ),
            header: P2PPacketHeader.fromBytes(datagram.data),
            datagram: datagram.data,
          ));
        } catch (e) {
          logger?.call(e.toString());
        }
      },
    );
  }

  @override
  void stop() {
    _socket?.close();
    _socket = null;
  }

  @override
  void send(
    final Iterable<P2PFullAddress> fullAddresses,
    final Uint8List datagram,
  ) {
    if (_socket == null) return;
    for (final peerFullAddress in fullAddresses) {
      if (peerFullAddress.type == fullAddress.type) {
        _socket!.send(datagram, peerFullAddress.address, peerFullAddress.port);
      }
    }
  }
}
