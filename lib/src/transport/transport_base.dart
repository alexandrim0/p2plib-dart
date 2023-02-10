part of 'transport.dart';

abstract class TransportBase {
  int ttl;
  final FullAddress bindAddress;
  Future<void> Function(Packet packet)? onMessage;
  void Function(String)? logger;

  TransportBase({
    required this.bindAddress,
    this.onMessage,
    this.ttl = 5,
    this.logger,
  });

  Future<void> start();

  void stop();

  void send(
    final Iterable<FullAddress> fullAddresses,
    final Uint8List datagram,
  );

  @override
  String toString() => bindAddress.toString();
}
