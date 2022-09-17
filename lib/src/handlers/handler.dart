import 'dart:typed_data';

import '../../src/router.dart';
import '../../src/peer.dart';
import '../../src/packet/header.dart';

abstract class TopicHandler {
  final Router router;

  TopicHandler(this.router) {
    router.p2pPackets.stream
        .where((event) => topics().contains(event.header.topic))
        .listen((event) {
      onMessage(event.header, event.data, event.peer);
    });
  }

  void onMessage(Header header, Uint8List data, Peer peer);

  Uint64List topics();
}
