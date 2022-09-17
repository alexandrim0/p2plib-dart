import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../settings.dart';
import '../../src/peer.dart';

class UdpData {
  final Peer peer;
  final Uint8List data;
  const UdpData(this.peer, this.data);
}

bool hasInterface(List<InternetAddress> interfaces, InternetAddressType type) {
  for (var interface in interfaces) {
    if (interface.type == type) {
      return true;
    }
  }
  return false;
}

class Udp {
  final InternetAddressType type;
  RawDatagramSocket? _socket;
  final int port;
  final data = StreamController<UdpData>.broadcast();
  bool isRunning = false;
  final Duration reconnectTimeout = const Duration(milliseconds: 1000);
  Completer? _socketCloseCompleter;
  Completer? _restartCompleter;

  Udp({required this.type, required this.port});

  Future<void> start() async {
    if (_restartCompleter != null) return _restartCompleter!.future;
    _restartCompleter = Completer();
    await stop();

    _socket = await RawDatagramSocket.bind(
      (type == InternetAddressType.IPv4)
          ? InternetAddress.anyIPv4
          : InternetAddress.anyIPv6,
      port,
      reuseAddress: true,
      reusePort: false,
      ttl: 240,
    );

    _socket?.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null && isRunning) {
            data.add(UdpData(
              Peer(datagram.address, datagram.port),
              datagram.data,
            ));
          }
        } else if (event == RawSocketEvent.closed) {
          _socket = null;
          _socketCloseCompleter?.complete();
        }
      },
      onError: (Object error) {
        if (isRunning) {
          Future.delayed(reconnectTimeout, () async => await start());
        }
      },
      cancelOnError: false,
    );
    _socketCloseCompleter = Completer();

    isRunning = true;
    _restartCompleter!.complete();
    _restartCompleter = null;
    return Future.value();
  }

  Future<void> stop() async {
    isRunning = false;
    _socket?.close();
    await _socketCloseCompleter?.future.timeout(Settings.defaultTimeout);
    _socketCloseCompleter = null;
    _socket = null;
    return Future.value();
  }

  int send(Peer peer, Uint8List data) {
    if (peer.address.type != type) return 0;
    int? bytes = _socket?.send(data, peer.address, peer.port);
    return bytes ?? 0;
  }
}

class UdpConnection {
  final Map<InternetAddressType, Udp> connections = {};
  int ipv4Port;
  int ipv6Port;
  List<InternetAddress> networkAddresses = <InternetAddress>[];
  final localAddresses = <Peer>[];
  final udpData = StreamController<UdpData>.broadcast();

  Completer? _startCompleter;

  UdpConnection({this.ipv4Port = 7345, this.ipv6Port = 7344});

  Future<void> start() async {
    if (_startCompleter != null) {
      return _startCompleter!.future.timeout(Settings.defaultTimeout);
    }
    _startCompleter = Completer();

    await stop();
    networkAddresses = await _collectAddresses();

    if (hasInterface(networkAddresses, InternetAddressType.IPv4)) {
      connections[InternetAddressType.IPv4] = Udp(
        type: InternetAddressType.IPv4,
        port: ipv4Port,
      )..data.stream.asBroadcastStream().listen(
            (event) => udpData.add(event),
          );
      localAddresses.add(Peer(InternetAddress.anyIPv4, ipv4Port));
    }

    if (hasInterface(networkAddresses, InternetAddressType.IPv6)) {
      connections[InternetAddressType.IPv6] = Udp(
        type: InternetAddressType.IPv6,
        port: ipv6Port,
      )..data.stream.asBroadcastStream().listen(
            (event) => udpData.add(event),
          );
      localAddresses.add(Peer(InternetAddress.anyIPv6, ipv6Port));
    }

    List<Future<void>> startRequests = [];
    connections.forEach((key, value) {
      startRequests.add(value.start());
    });
    await Future.wait(startRequests);

    _startCompleter!.complete();
    _startCompleter = null;
  }

  Future<void> stop() async {
    networkAddresses.clear();
    localAddresses.clear();
    List<Future<void>> stopRequests = [];
    for (var connection in connections.values) {
      stopRequests.add(connection.stop());
    }
    await Future.wait(stopRequests);
    return Future.value();
  }

  List<InternetAddress> get addresses => networkAddresses;

  Future<List<InternetAddress>> _collectAddresses() async {
    final addresses = <InternetAddress>[];
    for (var interface in await NetworkInterface.list()) {
      addresses.addAll(interface.addresses);
    }
    return addresses;
  }

  int send(Peer peer, Uint8List data) {
    int bytes = 0;
    for (var connection in connections.values) {
      final n = connection.send(peer, data);
      bytes = n != 0 ? n : bytes;
    }
    return bytes;
  }
}
