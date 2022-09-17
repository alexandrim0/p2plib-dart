import 'dart:async';
import 'dart:typed_data';
import 'package:p2plib/p2plib.dart';

class CanaryPacket {
  static int topic = 4000;

  Uint8List pack() {
    final header = Header(topic, genPacketId(), PubKey.zeros(), PubKey.zeros(),
        Encrypted.no, Ack.no);
    return header.serialize();
  }

  bool check(Uint8List data) {
    try {
      if (data.length < Header.length) return false;
      final header = Header.deserialize(data);
      if (header.topic != topic) return false;
    } catch (_) {}
    return false;
  }
}

class CanaryEvent {
  final Peer peer;
  final bool isOnline;
  final DateTime? lastSeen;
  const CanaryEvent(
      {required this.peer, required this.isOnline, this.lastSeen});

  @override
  bool operator ==(Object other) {
    return other is CanaryEvent &&
        peer == other.peer &&
        isOnline == other.isOnline;
  }

  @override
  int get hashCode {
    return Object.hashAll([peer, isOnline]);
  }
}

class Canary {
  final events = StreamController<CanaryEvent>.broadcast();
  final Set<Peer> _serversToPing = {};
  final int port;
  late UdpConnection connection;
  final Map<Peer, int> _failedPingAttemps = {};
  int processId = 0;

  Duration pingPeriod = const Duration(seconds: 30);
  int maxPingAttempts = 3;

  Canary({required this.port}) {
    connection = UdpConnection(ipv4Port: port);
    connection.udpData.stream.asBroadcastStream().listen((event) {
      _onMessage(event.data, event.peer);
    }, onError: (Object error) async {
      await _connect();
    });
  }

  Future<void> run() async {
    await _connect();
    _onTimer(++processId);
  }

  void addServerToPing(Peer server) {
    _serversToPing.add(server);
  }

  Future<void> _connect() async {
    await connection.start();
  }

  void _onMessage(Uint8List data, Peer peer) {
    _failedPingAttemps[peer] = 0;
    events.add(CanaryEvent(peer: peer, isOnline: true));
  }

  void _onTimer(int pid) {
    if (pid != processId) return;
    for (var server in _serversToPing) {
      _ping(server);

      final attempt = _failedPingAttemps[server] ?? 0;
      if (attempt >= maxPingAttempts) {
        _notifyOffline(server, null);
      }
    }
    Future.delayed(pingPeriod, () => _onTimer(pid));
  }

  void _ping(Peer peer) {
    int attempt = _failedPingAttemps[peer] ?? 0;
    _failedPingAttemps[peer] = attempt + 1;
    connection.send(peer, CanaryPacket().pack());
  }

  void _notifyOffline(Peer peer, DateTime? lastSeen) {
    _failedPingAttemps[peer] = 0;
    events.add(CanaryEvent(peer: peer, isOnline: false, lastSeen: lastSeen));
  }
}
