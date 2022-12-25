part of 'transport.dart';

class P2PUdpTransport extends P2PTransport {
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
        callback!(P2PPacket(
          header: P2PPacketHeader.fromBytes(
            datagram.data,
            FullAddress(address: datagram.address, port: datagram.port),
          ),
          datagram: datagram.data,
        ));
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
    final Iterable<FullAddress> fullAddresses,
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
