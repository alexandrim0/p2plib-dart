part of 'router.dart';

/// Interface class with base functions such as init(), start(), stop()
/// Also it keeps Routes and can manipulate with them

abstract class RouterBase {
  final Map<PeerId, Route> routes = {};
  final List<TransportBase> transports = [];
  final Duration keepalivePeriod;
  final Crypto crypto;

  late Duration messageTTL;
  late Duration peerAddressTTL = keepalivePeriod * 2;

  /// Defines how much nodes will be used for delivery
  var useForwardersLimit = 2;

  void Function(String)? logger;

  late final PeerId _selfId;

  var _isRun = false;

  RouterBase({
    final Crypto? crypto,
    final List<TransportBase>? transports,
    this.messageTTL = const Duration(seconds: 3),
    this.keepalivePeriod = const Duration(seconds: 15),
    this.logger,
  }) : crypto = crypto ?? Crypto() {
    this.transports.addAll(transports ??
        [
          TransportUdp(
            bindAddress: FullAddress(
              address: InternetAddress.anyIPv4,
              port: TransportUdp.defaultPort,
            ),
            ttl: messageTTL.inSeconds,
          ),
          TransportUdp(
            bindAddress: FullAddress(
              address: InternetAddress.anyIPv6,
              port: TransportUdp.defaultPort,
            ),
            ttl: messageTTL.inSeconds,
          ),
        ]);
  }

  bool get isRun => _isRun;
  bool get isNotRun => !_isRun;

  PeerId get selfId => _selfId;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  set maxStoredHeaders(int value) => Route.maxStoredHeaders = value;

  Future<Uint8List> init([Uint8List? seed]) async {
    final cryptoKeys = await crypto.init(seed);
    _selfId = PeerId.fromKeys(
      encryptionKey: cryptoKeys.encPubKey,
      signKey: cryptoKeys.signPubKey,
    );
    return cryptoKeys.seed;
  }

  Future<void> start() async {
    if (_isRun) return;
    if (transports.isEmpty) {
      throw ExceptionTransport('Need at least one Transport!');
    }
    for (final transport in transports) {
      transport
        ..logger = logger
        ..onMessage = onMessage
        ..ttl = messageTTL.inSeconds;
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

  /// Returns cached addresses or who can forward
  Iterable<FullAddress> resolvePeerId(final PeerId peerId) {
    final route = routes[peerId];
    if (route == null || route.isEmpty) {
      final result = <FullAddress>{};
      for (final a in routes.values.where((e) => e.canForward)) {
        result.addAll(a.addresses.keys);
      }
      return result.take(useForwardersLimit);
    } else {
      return route.getActualAddresses(
        staleAt: _now - peerAddressTTL.inMilliseconds,
      );
    }
  }

  void _log(Object message) => logger?.call(message.toString());
}
