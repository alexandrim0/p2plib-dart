part of 'router.dart';

/// Interface class with base functions such as init(), start(), stop()
/// Also it keeps Routes and can manipulate with them

abstract class P2PRouterBase {
  static const defaultPort = 2022;
  static const defaultPeriod = Duration(seconds: 1);
  static const defaultTimeout = Duration(seconds: 3);
  static const defaultAddressTTL = Duration(seconds: 30);

  final Map<P2PPeerId, P2PRoute> routes = {};
  final Iterable<P2PTransportBase> transports;
  final Duration keepalivePeriod;
  final P2PCrypto crypto;

  var transportTTL = defaultTimeout.inSeconds;
  var peerAddressTTL = defaultAddressTTL;
  var requestTimeout = defaultTimeout;
  var useForwardersCount = 2;
  var maxForwardsCount = 1;
  var maxStoredHeaders = 0;
  var preserveLocalAddress = false; // More efficient for relay node

  void Function(String)? logger;

  late final P2PPeerId _selfId;

  var _isRun = false;

  P2PRouterBase({
    final P2PCrypto? crypto,
    final Iterable<P2PTransportBase>? transports,
    this.keepalivePeriod = const Duration(seconds: 15),
    this.logger,
  })  : crypto = crypto ?? P2PCrypto(),
        transports = transports ??
            [
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv4,
                isLocal: false,
                port: defaultPort,
              )),
              P2PUdpTransport(
                  fullAddress: P2PFullAddress(
                address: InternetAddress.anyIPv6,
                isLocal: false,
                port: defaultPort,
              )),
            ];

  bool get isRun => _isRun;
  bool get isNotRun => !_isRun;

  P2PPeerId get selfId => _selfId;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<P2PCryptoKeys> init([final P2PCryptoKeys? keys]) async {
    final cryptoKeys = await crypto.init(keys);
    _selfId = P2PPeerId.fromKeys(
      encryptionKey: cryptoKeys.encPublicKey,
      signKey: cryptoKeys.signPublicKey,
    );
    return cryptoKeys;
  }

  Future<void> start() async {
    if (_isRun) return;
    if (transports.isEmpty) {
      throw P2PExceptionTransport('Need at least one P2PTransport!');
    }
    for (final t in transports) {
      t.ttl = transportTTL;
      t.callback = onMessage;
      await t.start();
    }
    _isRun = true;
    _log('Start listen $transports with key $_selfId');
  }

  void stop() {
    _isRun = false;
    for (final t in transports) {
      t.stop();
    }
  }

  /// returns null if message is processed and children have to return
  Future<P2PPacket?> onMessage(final P2PPacket packet);

  void sendDatagram({
    required final Iterable<P2PFullAddress> addresses,
    required final Uint8List datagram,
  }) {
    for (final t in transports) {
      t.send(addresses, datagram);
    }
  }

  // TBD
  void addRoute(final P2PRoute route) {}

  P2PRoute? removeRoute(final P2PPeerId peerId) => routes.remove(peerId);

  bool getPeerStatus(final P2PPeerId peerId) =>
      (routes[peerId]?.lastSeen ?? 0) + requestTimeout.inMilliseconds > _now;

  /// Returns cached addresses or who can forward
  Iterable<P2PFullAddress> resolvePeerId(final P2PPeerId peerId) {
    final route = routes[peerId];
    if (route == null || route.isEmpty) {
      final result = <P2PFullAddress>{};
      for (final a in routes.values.where((e) => e.canForward)) {
        result.addAll(a.addresses.keys);
      }
      return result.take(useForwardersCount);
    } else {
      return route.getActualAddresses(
        staleAt: _now - peerAddressTTL.inMilliseconds,
        preserveLocal: preserveLocalAddress,
      );
    }
  }

  void _log(Object message) => logger?.call(message.toString());
}
