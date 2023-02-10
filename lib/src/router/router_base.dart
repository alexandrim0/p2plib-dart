part of 'router.dart';

/// Interface class with base functions such as init(), start(), stop()
/// Also it keeps Routes and can manipulate with them

abstract class RouterBase {
  static const defaultPeriod = Duration(seconds: 1);
  static const defaultTimeout = Duration(seconds: 3);
  static const defaultAddressTTL = Duration(seconds: 30);

  final Map<PeerId, Route> routes = {};
  final Iterable<TransportBase> transports;
  final Duration keepalivePeriod;
  final Crypto crypto;

  var peerAddressTTL = defaultAddressTTL;
  var peerOnlineTimeout = defaultTimeout;
  var requestTimeout = defaultTimeout;
  var useForwardersCount = 2;
  var maxForwardsCount = 1;

  void Function(String)? logger;

  late final PeerId _selfId;

  var _isRun = false;

  RouterBase({
    final Crypto? crypto,
    final Iterable<TransportBase>? transports,
    this.keepalivePeriod = const Duration(seconds: 15),
    this.logger,
  })  : crypto = crypto ?? Crypto(),
        transports = transports ??
            [
              TransportUdp(
                bindAddress: FullAddress(
                  address: InternetAddress.anyIPv4,
                  port: TransportUdp.defaultPort,
                ),
                ttl: defaultTimeout.inSeconds,
              ),
              TransportUdp(
                bindAddress: FullAddress(
                  address: InternetAddress.anyIPv6,
                  port: TransportUdp.defaultPort,
                ),
                ttl: defaultTimeout.inSeconds,
              ),
            ];

  bool get isRun => _isRun;
  bool get isNotRun => !_isRun;

  PeerId get selfId => _selfId;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  set maxStoredHeaders(int value) => Route.maxStoredHeaders = value;

  Future<CryptoKeys> init([final CryptoKeys? keys]) async {
    final cryptoKeys = await crypto.init(keys);
    _selfId = PeerId.fromKeys(
      encryptionKey: cryptoKeys.encPublicKey,
      signKey: cryptoKeys.signPublicKey,
    );
    return cryptoKeys;
  }

  Future<void> start() async {
    if (_isRun) return;
    if (transports.isEmpty) {
      throw ExceptionTransport('Need at least one Transport!');
    }
    for (final transport in transports) {
      transport
        ..logger = logger
        ..onMessage = onMessage;
      await transport.start();
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

  /// throws StopProcessing if message is processed and children have to return
  Future<Packet> onMessage(final Packet packet);

  void sendDatagram({
    required final Iterable<FullAddress> addresses,
    required final Uint8List datagram,
  }) {
    for (final t in transports) {
      t.send(addresses, datagram);
    }
  }

  bool getPeerStatus(final PeerId peerId) =>
      (routes[peerId]?.lastSeen ?? 0) + peerOnlineTimeout.inMilliseconds > _now;

  /// Returns cached addresses or who can forward
  Iterable<FullAddress> resolvePeerId(final PeerId peerId) {
    final route = routes[peerId];
    if (route == null || route.isEmpty) {
      final result = <FullAddress>{};
      for (final a in routes.values.where((e) => e.canForward)) {
        result.addAll(a.addresses.keys);
      }
      return result.take(useForwardersCount);
    } else {
      return route.getActualAddresses(
        staleAt: _now - peerAddressTTL.inMilliseconds,
      );
    }
  }

  void _log(Object message) => logger?.call(message.toString());
}
