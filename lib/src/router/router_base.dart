part of 'router.dart';

/// Abstract base class for network routers.
///
/// This class provides the fundamental functionality for managing network
/// communication, including initialization, starting and stopping the router,
/// and handling routes. It defines the core interface for interacting with the
/// network and is intended to be extended by concrete router implementations.
abstract class RouterBase {
  /// Creates a new [RouterBase] instance.
  ///
  /// [crypto] The cryptography instance to use for encryption and signing. If
  ///   not provided, a default [Crypto] instance is created.
  /// [transports] The list of transports to use for network communication. If
  ///   not provided, default UDP transports for IPv4 and IPv6 are created.
  /// [messageTTL] The time-to-live for messages, specifying how long they
  ///   should be considered valid. Defaults to 3 seconds.
  /// [keepalivePeriod] The interval at which keepalive messages are sent to
  ///   maintain connections with peers. Defaults to 15 seconds.
  /// [logger] The logger to use for logging events.
  RouterBase({
    Crypto? crypto,
    List<TransportBase>? transports,
    this.messageTTL = const Duration(seconds: 3),
    this.keepalivePeriod = const Duration(seconds: 15),
    this.logger,
  }) : crypto = crypto ?? Crypto() {
    // Initialize transports with provided or default UDP transports.
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

  /// The self ID of the router.
  ///
  /// This ID uniquely identifies the router within the network.
  late final PeerId _selfId;

  /// Whether the router is currently running.
  var _isRun = false;

  /// Whether the router is currently running.
  bool get isRun => _isRun;

  /// Whether the router is not currently running.
  bool get isNotRun => !_isRun;

  /// The self ID of the router.
  PeerId get selfId => _selfId;

  /// The maximum number of stored headers for routes.
  int get maxStoredHeaders => Route.maxStoredHeaders;

  /// The current time in milliseconds since the epoch.
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
    if (_isRun) return; 
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
    _isRun = true;
    _log('Start listen $transports with key $_selfId');
  }

  /// Stops the router.
  ///
  /// This method stops all configured transports, effectively shutting down
  /// the router and preventing further message processing.
  void stop() {
    _isRun = false;
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
    // Look up the route for the given peer ID.
    final route = routes[peerId];
    
    // If the route is not found or is empty:
    if (route == null || route.isEmpty) {
      // Create a set to store the resolved addresses.
      final result = <FullAddress>{};
      
      // Iterate through all routes that can forward messages.
      for (final a in routes.values.where((e) => e.canForward)) {
        // Add the addresses of the forwarder to the result set.
        result.addAll(a.addresses.keys);
      }
      
      // Return up to `useForwardersLimit` addresses from the result set.
      return result.take(useForwardersLimit);
    } else { 
      // If the route is found, return the actual addresses associated with it,
      // filtering out stale addresses based on `peerAddressTTL`.
      return route.getActualAddresses(
        staleAt: _now - peerAddressTTL.inMilliseconds,
      );
    }
  }

  /// Logs a message using the provided logger.
  ///
  /// [message] The message to be logged.
  ///
  /// This method checks if a logger is configured and, if so, calls the logger
  /// function with the provided message converted to a string. If no logger
  /// is configured, the message is ignored.
  void _log(Object message) => logger?.call(message.toString());
}
