part of 'router.dart';

/// Abstract base class for network routers.
///
/// This class provides the fundamental functionality for managing network
/// communication, including initialization, starting and stopping the router,
/// and handling routes. It defines the core interface for interacting with the
/// network and is intended to be extended by concrete router implementations.
abstract class RouterBase {
  RouterBase({
    Crypto? crypto,
    List<TransportBase>? transports,
    this.messageTTL = const Duration(seconds: 3),
    this.keepalivePeriod = const Duration(seconds: 15),
    this.logger,
  }) : crypto = crypto ?? Crypto() {
    // Initialize transports with provided or default UDP transports.
    this.transports.addAll(
      transports ??
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
          ],
    );
  }

  /// The cryptography instance used for encryption and signing.
  final Crypto crypto;

  /// The keepalive period, specifying the interval for sending keepalive
  /// messages to peers.
  final Duration keepalivePeriod;

  /// The routes maintained by the router, stored as a map of [PeerId] to
  /// [Route].
  final Map<PeerId, Route> routes = {};

  /// The transports used for network communication.
  final List<TransportBase> transports = [];

  /// The message time-to-live, specifying how long messages are considered
  /// valid.
  late Duration messageTTL;

  /// The peer address time-to-live, specifying how long peer addresses are
  /// considered valid. Defaults to twice the keepalive period.
  late Duration peerAddressTTL = keepalivePeriod * 2;

  /// Defines the maximum number of forwarders to use for message delivery.
  ///
  /// This value limits the number of intermediate peers that a message can be
  /// routed through to reach its destination.
  int useForwardersLimit = 2;

  /// The logger used for logging events.
  void Function(String)? logger;

  late final PeerId _selfId;

  var _isRunning = false;

  bool get isRunning => _isRunning;

  bool get isNotRunning => !_isRunning;

  PeerId get selfId => _selfId;

  /// The maximum number of stored headers for routes.
  int get maxStoredHeaders => Route.maxStoredHeaders;

  int get _now => DateTime.timestamp().millisecondsSinceEpoch;

  /// Sets the maximum number of stored headers for routes.
  set maxStoredHeaders(int value) => Route.maxStoredHeaders = value;

  /// Initializes the router.
  ///
  /// [seed] An optional seed to use for cryptographic key generation. If not
  ///   provided, a random seed is generated.
  ///
  /// Returns the seed used for initialization.
  Future<Uint8List> init([Uint8List? seed]) async {
    final cryptoKeys = await crypto.init(seed);
    _selfId = PeerId.fromKeys(
      encryptionKey: cryptoKeys.encPubKey,
      signKey: cryptoKeys.signPubKey,
    );
    return cryptoKeys.seed;
  }

  /// Starts the router.
  ///
  /// This method initializes and starts all configured transports, making the
  /// router ready to receive and send messages.
  ///
  /// Throws an [ExceptionTransport] if no transports are configured.
  Future<void> start() async {
    if (_isRunning) return;
    if (transports.isEmpty) {
      throw const ExceptionTransport('Need at least one Transport!');
    }
    for (final transport in transports) {
      transport
        ..logger = logger
        ..onMessage = onMessage
        ..ttl = messageTTL.inSeconds;
      await transport.start();
    }
    _isRunning = true;
    _log('Start listen $transports with key $_selfId');
  }

  /// Stops the router.
  ///
  /// This method stops all configured transports, effectively shutting down
  /// the router and preventing further message processing.
  void stop() {
    _isRunning = false;
    for (final t in transports) {
      t.stop();
    }
  }

  /// Handles incoming messages.
  ///
  /// [packet] The incoming [Packet] to be processed.
  ///
  /// This method is called by the transports when a new message is received.
  /// It is responsible for routing the message to the appropriate destination
  /// or handling it locally.
  ///
  /// Throws a [StopProcessing] exception if the message has been fully
  /// processed and further processing by child routers should be stopped.
  Future<Packet> onMessage(Packet packet);

  /// Sends a datagram to the specified addresses.
  ///
  /// [addresses] An iterable of [FullAddress] objects representing the
  ///   destinations to send the datagram to.
  /// [datagram] The [Uint8List] containing the datagram data to be sent.
  ///
  /// This method iterates through all available transports and sends the
  /// datagram using each one, ensuring that the message is delivered to all
  /// specified destinations.
  void sendDatagram({
    required Iterable<FullAddress> addresses,
    required Uint8List datagram,
  }) {
    for (final t in transports) {
      t.send(addresses, datagram);
    }
  }

  /// Resolves a Peer ID to a set of network addresses.
  ///
  /// This method attempts to find the network addresses associated with a given
  /// Peer ID. If the Peer ID is known and has a route, the method returns the
  /// actual addresses associated with the route, filtering out stale addresses
  /// based on the `peerAddressTTL`.
  ///
  /// If the Peer ID is unknown or has no route, the method returns the
  /// addresses of forwarder peers that can potentially relay messages to the
  /// target peer. The number of forwarder addresses returned is limited by
  /// the `useForwardersLimit` property.
  ///
  /// [peerId] The ID of the peer to resolve.
  ///
  /// Returns an iterable of [FullAddress] objects representing the resolved
  /// addresses.
  Iterable<FullAddress> resolvePeerId(PeerId peerId) {
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
