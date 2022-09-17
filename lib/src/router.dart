import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:p2plib/p2plib.dart';

class P2PPacket {
  final Header header;
  final Uint8List data;
  final Peer peer;
  const P2PPacket(this.header, this.data, this.peer);
}

class LastSeenStatus {
  final DateTime timestamp;
  final bool status;
  const LastSeenStatus(this.timestamp, this.status);
}

class Router {
  final UdpConnection _connection;
  final Map<PubKey, Set<Peer>> _peers = {};
  Map<PubKey, DateTime> _statusCheckTasks = {};
  final Map<PubKey, LastSeenStatus> _lastSeen = {};
  final PubKey _pubKey;
  final _waitingAcks = <int, Completer>{};
  final KeyPairData encryptionKeyPair;
  final KeyPairData signKeyPair;
  BootsrapServerHandler? bootstrapServerFinder;
  late EchoHandler _echoHandler;
  Timer? _bootstrapRegistrationTimer;
  Timer? _pingTimer;
  bool _isRunning = false;

  final p2pPackets = StreamController<P2PPacket>.broadcast();

  Router(this._connection,
      {required this.encryptionKeyPair,
      required this.signKeyPair,
      Peer? bootstrapServerAddress,
      Peer? bootstrapServerAddressIpv6})
      : _pubKey = PubKey.keys(
            encryptionKey: encryptionKeyPair.pubKey,
            signKey: signKeyPair.pubKey) {
    _echoHandler = EchoHandler(this);
    _connection.udpData.stream.asBroadcastStream().listen((event) {
      if (!_isRunning) return;
      _onMessage(event.peer, event.data);
    });
    setBootstrapServer(bootstrapServerAddress, bootstrapServerAddressIpv6);
  }

  Future<void> setBootstrapServer(Peer? ipv4Address, Peer? ipv6Address) async {
    bootstrapServerFinder = null;
    if (ipv4Address != null || ipv6Address != null) {
      bootstrapServerFinder = BootsrapServerHandler(
          router: this,
          serverAddressIpv4: ipv4Address,
          serverAddressIpv6: ipv6Address);
    }
    if (_isRunning) _registreOnBootstrap();
    return Future.value();
  }

  bool getPeerStatus(PubKey peerId) {
    final status = _getPeerStatus(peerId);
    _echoHandler.echo.add(EchoResult(peerId, status));
    return status;
  }

  Future<bool> pingPeer(PubKey peerId,
      {bool staticCheck = true, Duration? timeout}) async {
    timeout ??= Settings.pingTimeout;
    bool status = false;
    if (staticCheck) status = getPeerStatus(peerId);
    if (status) {
      Future.microtask(() async {
        try {
          await sendTo(1, peerId, randomBytes(length: 8),
              encrypted: Encrypted.encrypted,
              ack: Ack.required,
              timeout: timeout);
        } catch (_) {}
      });
      return Future.value(status);
    }
    try {
      await sendTo(1, peerId, randomBytes(length: 8),
          encrypted: Encrypted.encrypted, ack: Ack.required, timeout: timeout);
      status = true;
    } catch (_) {}
    if (!status) status = _getPeerStatus(peerId);
    _echoHandler.echo.add(EchoResult(peerId, status));
    return Future.value(status);
  }

  StreamSubscription<bool> onPeerStatusChanged(
      void Function(bool status) onChange, PubKey filter) {
    final sub = _echoHandler.echo.stream
        .asBroadcastStream()
        .where((event) => filter == event.pubKey)
        .map((event) => event.status)
        .listen((event) async {
      onChange(event);
      _addCheckStatusTask(filter, DateTime.now());
    });

    return sub;
  }

  Future<void> run() async {
    await stop();
    _isRunning = true;
    await _connection.start();
    await _registreOnBootstrap();
    _bootstrapRegistrationTimer =
        Timer.periodic(Settings.bootstrapRegistrationTimeout, (timer) async {
      await _registreOnBootstrap();
    });
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkLastSeenStatus();
    });
    _addMyLocalConnection();
  }

  Future<void> stop() async {
    _isRunning = false;
    await _connection.stop();
    _bootstrapRegistrationTimer?.cancel();
    _pingTimer?.cancel();
    await Future.delayed(const Duration(milliseconds: 300));
    return Future.value();
  }

  PubKey get pubKey => _pubKey;
  UdpConnection get connection => _connection;

  Future<void> sendSigned(int topic, Peer peer, Uint8List data,
      {PubKey? dstKey, Duration? timeout}) async {
    dstKey ??= PubKey.zeros();
    final packetId = genPacketId();
    final packet = await _pack(
        Header(topic, packetId, pubKey, dstKey, Encrypted.signed, Ack.no),
        data);
    sendDirectly(peer, packet);
    return Future.value();
  }

  Future<void> sendEncrypted(int topic, Peer peer, Uint8List data,
      {required PubKey dstKey, Ack ack = Ack.no, Duration? timeout}) async {
    final packetId = genPacketId();
    final packet = await _pack(
        Header(topic, packetId, pubKey, dstKey, Encrypted.encrypted, ack),
        data);

    sendDirectly(peer, packet);
    return _checkAck(ack, packetId, packet,
        dstKey: dstKey, peer: peer, timeout: timeout);
  }

  int sendDirectly(Peer peer, Uint8List data) {
    if (!Settings.enableDirectDataTransfer) {
      return 0;
    }
    return _connection.send(peer, data);
  }

  Future<void> sendDirectlyEncrypted(
      Peer peer, int topic, PubKey peerPubKey, Uint8List data,
      {Encrypted encrypted = Encrypted.encrypted,
      Ack ack = Ack.no,
      Duration? timeout}) async {
    final packetId = genPacketId();
    final packet = await _pack(
        Header(topic, packetId, _pubKey, peerPubKey, encrypted, ack), data);
    sendDirectly(peer, packet);
    return _checkAck(ack, packetId, packet,
        dstKey: peerPubKey, peer: peer, timeout: timeout);
  }

  Future<void> sendTo(int topic, PubKey peerPubKey, Uint8List data,
      {Encrypted encrypted = Encrypted.encrypted,
      Ack ack = Ack.no,
      Duration? timeout}) async {
    final packetId = genPacketId();
    final packet = await _pack(
        Header(topic, packetId, _pubKey, peerPubKey, encrypted, ack), data);
    await _send(peerPubKey, packet);

    return _checkAck(ack, packetId, packet,
        dstKey: peerPubKey, peerId: peerPubKey, timeout: timeout);
  }

  void resetKnownHosts() {
    _peers.clear();
  }

  void addPeer(PubKey key, Peer peer, {bool enableSearch = true}) {
    if (_isProxy(peer)) return;
    final peers = _peers[key] ?? <Peer>{};
    peers.add(peer);
    _peers[key] = peers;
    if (peers.length == 1 && enableSearch) {
      _search(key).then((value) => _peers[key]!.addAll(value));
    }
  }

  bool _getPeerStatus(PubKey peerId) {
    if (peerId == pubKey) return true;
    final lastSeen = _lastSeen[peerId];
    if (lastSeen == null) return false;

    final now = DateTime.now();
    if ((now.millisecondsSinceEpoch -
            lastSeen.timestamp.millisecondsSinceEpoch) >
        Settings.offlineTimeout.inMilliseconds) {
      return false;
    }
    return true;
  }

  void _addMyLocalConnection() {
    if (_connection.connections.containsKey(InternetAddressType.IPv4)) {
      addPeer(_pubKey, Peer(InternetAddress.loopbackIPv4, _connection.ipv4Port),
          enableSearch: false);
    }
    if (_connection.connections.containsKey(InternetAddressType.IPv6)) {
      addPeer(_pubKey, Peer(InternetAddress.loopbackIPv6, _connection.ipv6Port),
          enableSearch: false);
    }
  }

  void _addCheckStatusTask(PubKey key, DateTime dateTime) {
    if (_statusCheckTasks.containsKey(key)) return;
    _statusCheckTasks[key] = dateTime;
  }

  Future<void> _send(PubKey peerPubKey, Uint8List data) async {
    final search = _peersByPubKey(peerPubKey);
    // send to proxy server
    if (Settings.enableBootstrapProxy) {
      _sendProxy(data);
    }
    final peers = await search;
    for (var peer in peers) {
      sendDirectly(peer, data);
    }
  }

  void _sendProxy(Uint8List data) {
    if (bootstrapServerFinder != null) {
      if (bootstrapServerFinder!.serverAddressIpv4 != null) {
        sendDirectly(bootstrapServerFinder!.serverAddressIpv4!, data);
      }
      if (bootstrapServerFinder!.serverAddressIpv6 != null) {
        sendDirectly(bootstrapServerFinder!.serverAddressIpv6!, data);
      }
    }
  }

  bool _isProxy(Peer peer) {
    final finder = bootstrapServerFinder;
    if (finder == null) return false;
    if (finder.serverAddressIpv4 == peer || finder.serverAddressIpv6 == peer) {
      return true;
    }
    return false;
  }

  Future<Set<Peer>> _peersByPubKey(PubKey key) async {
    if (_peers[key] == null || _peers[key]!.isEmpty) {
      final peers = await _search(key);
      _peers[key] = peers;
    }
    return Future.value(_peers[key]);
  }

  Future<Uint8List> _pack(Header header, Uint8List data) async {
    final bytesBuilder = BytesBuilder(copy: false);
    bytesBuilder.add(header.serialize());

    var body = data;
    if (header.encrypted == Encrypted.encrypted) {
      body = await P2PCrypto().encrypt(
          header.dstKey.encryptionKey(), encryptionKeyPair.secretKey, body);
    } else if (header.encrypted == Encrypted.signed) {
      body = await P2PCrypto().sign(signKeyPair.secretKey, body);
    }
    bytesBuilder.add(body);
    return bytesBuilder.toBytes();
  }

  void _onMessage(Peer peer, Uint8List data) async {
    if (data.length < Packet.minimalPacketLength) return;
    try {
      final header = Header.deserialize(data);
      if (header.ack == Ack.required) {
        await _onAckRequest(header, peer);
      }

      if (header.dstKey != pubKey) return;
      final body = await _decrypt(header, data.sublist(Header.length));
      if (header.topic == AckPacket.topic) {
        // ack packet
        _onAckPacket(header.srcKey, body);
        addPeer(header.srcKey, peer, enableSearch: false);
        _updateLastSeen(header.srcKey);
        return;
      }
      // add only reliable peers
      if (header.encrypted == Encrypted.encrypted ||
          header.encrypted == Encrypted.signed) {
        addPeer(header.srcKey, peer, enableSearch: false);
        _updateLastSeen(header.srcKey);
      }
      p2pPackets.add(P2PPacket(header, body, peer));
    } catch (_) {}
  }

  Future<void> _onAckRequest(Header header, Peer peer) async {
    await sendEncrypted(AckPacket.topic, peer, header.id,
        ack: Ack.no, dstKey: header.srcKey);
    return Future.value();
  }

  void _updateLastSeen(PubKey key) {
    _echoHandler.echo.add(EchoResult(key, true));
    _lastSeen[key] = LastSeenStatus(DateTime.now(), true);
  }

  Future<void> _checkAck(Ack ack, Uint8List packetId, Uint8List data,
      {required PubKey dstKey, Duration? timeout, Peer? peer, PubKey? peerId}) {
    timeout ??= Settings.ackResponseTimeout;
    if (ack == Ack.required) {
      final completer = Completer();
      final token = getAckToken(dstKey, packetId);
      _waitingAcks[token] = completer;
      Future.delayed(Settings.ackRepeatTimeout,
          () async => {_repeatAck(data, token, peer: peer, peerId: peerId)});
      return completer.future
          .timeout(timeout, onTimeout: () => _onAckTimeout(token));
    } else {
      return Future.value();
    }
  }

  void _repeatAck(Uint8List data, int token,
      {Peer? peer, PubKey? peerId}) async {
    if (!_waitingAcks.containsKey(token)) return;
    if (peer != null) sendDirectly(peer, data);
    if (peerId != null) await _send(peerId, data);
    Future.delayed(Settings.ackRepeatTimeout,
        () async => {_repeatAck(data, token, peer: peer, peerId: peerId)});
  }

  void _onAckPacket(PubKey srcKey, Uint8List packetId) {
    final token = getAckToken(srcKey, packetId);
    final completer = _waitingAcks[token];
    if (completer == null) return;
    _waitingAcks.remove(token);
    completer.complete();
  }

  int getAckToken(PubKey key, Uint8List packetId) {
    final data = combineLists(key.data, packetId);
    return RawToken(data: data, len: data.length).hashCode;
  }

  void _onAckTimeout(int id) {
    final completer = _waitingAcks[id];
    if (completer == null) return;
    _waitingAcks.remove(id);
    throw TimeoutException("ack timeout");
  }

  Future<Uint8List> _decrypt(Header header, Uint8List data) async {
    if (header.encrypted == Encrypted.encrypted) {
      return await P2PCrypto().decrypt(
          header.srcKey.encryptionKey(), encryptionKeyPair.secretKey, data);
    } else if (header.encrypted == Encrypted.signed) {
      return await P2PCrypto().openSign(header.srcKey.signKey(), data);
    }
    return data;
  }

  Future<void> _registreOnBootstrap() async {
    final finder = bootstrapServerFinder;
    if (finder == null) return;
    try {
      await finder.registerMe();
    } catch (_) {}
    return Future.value();
  }

  Future<Set<Peer>> _search(PubKey requestedPubKey) async {
    final peers = <Peer>{};
    if (!Settings.enableBootstrapSearch) return Future.value(peers);
    final searches = [bootstrapServerFinder?.findPeer(requestedPubKey)];

    for (final search in searches) {
      try {
        final peer = await search;
        if (peer is List<Peer>) {
          peers.addAll(peer);
        }
      } catch (_) {}
    }
    return Future.value(peers);
  }

  void _checkLastSeenStatus() {
    final now = DateTime.now();
    for (var key in _lastSeen.keys) {
      final lastSeen = _lastSeen[key];
      if (!lastSeen!.status) continue;
      final diff = (now.millisecondsSinceEpoch -
          lastSeen.timestamp.millisecondsSinceEpoch);
      if (diff > Settings.offlineTimeout.inMilliseconds) {
        _lastSeen[key] = LastSeenStatus(lastSeen.timestamp, false);
        _echoHandler.echo.add(EchoResult(key, false));
      }
    }

    final Map<PubKey, DateTime> newTasks = {};
    for (var key in _statusCheckTasks.keys) {
      final time = _statusCheckTasks[key];
      if (time == null) continue;
      Future.microtask(() async => await pingPeer(key));
    }
    _statusCheckTasks = newTasks;
  }
}
