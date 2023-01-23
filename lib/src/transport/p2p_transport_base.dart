part of 'transport.dart';

abstract class P2PTransportBase {
  int ttl;
  final P2PFullAddress fullAddress;
  void Function(P2PPacket)? callback;

  P2PTransportBase({required this.fullAddress, this.callback, this.ttl = 5});

  Future<void> start();

  void stop();

  void send(
    final Iterable<P2PFullAddress> fullAddresses,
    final Uint8List datagram,
  );

  @override
  String toString() => fullAddress.toString();
}
