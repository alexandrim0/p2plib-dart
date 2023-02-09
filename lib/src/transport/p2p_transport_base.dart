part of 'transport.dart';

abstract class P2PTransportBase {
  int ttl;
  final P2PFullAddress fullAddress;
  Future<void> Function(P2PPacket packet)? onMessage;
  void Function(String)? logger;

  P2PTransportBase({
    required this.fullAddress,
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
  String toString() => fullAddress.toString();
}
