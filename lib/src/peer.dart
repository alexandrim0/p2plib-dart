import 'dart:core';
import 'dart:io';

import 'pubkey.dart';

class IdPeer {
  final Peer peer;
  final PubKey pubKey;
  const IdPeer(this.peer, this.pubKey);
}

class Peer {
  final InternetAddress address;
  final int port;

  const Peer(this.address, this.port);

  @override
  bool operator ==(Object other) {
    if (other is Peer && other.address == address && other.port == port) {
      return true;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(address.hashCode, port.hashCode);

  @override
  String toString() {
    return '${address.host}:$port';
  }
}
