part of 'transport.dart';

abstract class TransportBase {
  TransportBase({
    required this.bindAddress,
    this.onMessage,
    this.ttl = 5,
    this.logger,
  });

  final FullAddress bindAddress;

  int ttl;

  void Function(String)? logger;

  Future<void> Function(Packet packet)? onMessage;

  Future<void> start();

  void stop();

  void send(
    Iterable<FullAddress> fullAddresses,
    Uint8List datagram,
  );

  @override
  String toString() => bindAddress.toString();
}
