part of 'transport.dart';

abstract class P2PTransportBase {
  int ttl;
  final P2PFullAddress bindAddress;
  Future<void> Function(P2PPacket packet)? onMessage;
  void Function(String)? logger;

  P2PTransportBase({
    required this.bindAddress,
    this.onMessage,
    this.ttl = 5,
    this.logger,
  });

  Future<void> start();

  void stop();

  void send(
    final Iterable<P2PFullAddress> fullAddresses,
    final Uint8List datagram,
  );

  @override
  String toString() => bindAddress.toString();
}
