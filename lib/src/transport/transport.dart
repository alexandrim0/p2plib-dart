import 'dart:io';
import 'dart:async';

import '/src/data/data.dart';

part 'udp_transport.dart';

abstract class P2PTransport {
  int ttl;
  final FullAddress fullAddress;
  void Function(P2PPacket)? callback;

  P2PTransport({required this.fullAddress, this.callback, this.ttl = 5});

  Future<void> start();

  void stop();

  void send(
    final Iterable<FullAddress> fullAddresses,
    final Uint8List datagram,
  );

  @override
  String toString() => fullAddress.toString();
}
