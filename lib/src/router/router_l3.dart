part of 'router.dart';

/// Router implementation for Layer 3 (Network Layer).
///
/// This class extends `RouterL2` and provides functionality for managing
/// network addresses and bootstrapping. It handles the discovery and
/// connection to bootstrap nodes, enabling the router to join the network.
class RouterL3 extends RouterL2 {
  RouterL3({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  });

  /// Stores the addresses associated with bootstrap nodes.
  ///
  /// This map is used to store the addresses of known bootstrap nodes, which
  /// are used to initially join the network.
  final Map<String, List<InternetAddress>> _addresses = {};

  /// Starts the router and binds to available network interfaces.
  ///
  /// This method initializes the router and starts listening for incoming
  /// messages on all available network interfaces. It also binds to the
  /// specified port and starts the base router.
  ///
  /// [port] The port to bind to. Defaults to `TransportUdp.defaultPort`.
  @override
  Future<void> start({int port = TransportUdp.defaultPort}) async {
    // Get all available network interfaces.
    final ifs = <InternetAddress>{};
    for (final nIf in await NetworkInterface.list()) {
      ifs.addAll(nIf.addresses);
    }

    // Bind to each interface using UDP transport.
    for (final address in ifs) {
      transports.add(
        TransportUdp(
          bindAddress: FullAddress(address: address, port: port),
        ),
      );
    }

    await super.start();
  }

  /// Stops the router and clears the transports.
  ///
  /// This method stops the router, clears the list of transports, and
  /// performs any necessary cleanup.
  @override
  void stop() {
    super.stop();
    transports.clear();
  }

  /// Adds a bootstrap node to the router.
  ///
  /// This method adds a bootstrap node to the router, allowing it to join the
  /// network. It resolves the DNS name of the bootstrap node, adds its
  /// addresses to the routing table, and restarts the router to establish
  /// connections.
  ///
  /// [bsName] The DNS name of the bootstrap node.
  /// [bsPeerId] The base64 encoded Peer ID of the bootstrap node.
  /// [port] The port to connect to. Defaults to `TransportUdp.defaultPort`.
  Future<void> addBootstrap({
    required String bsName,
    required String bsPeerId,
    int port = TransportUdp.defaultPort,
  }) async {
    // Stop the router before adding a bootstrap node to prevent conflicts
    // during the address resolution and routing table updates.
    stop();

    // Resolve the DNS name to get the IP addresses of the bootstrap node.
    _addresses[bsPeerId] = await InternetAddress.lookup(
      bsName,
    ).timeout(messageTTL);

    // Set address properties for the bootstrap node, marking it as static.
    final addressProperties = AddressProperties(isStatic: true);

    // Add the bootstrap node's addresses to the peer addresses in the
    // routing table.
    for (final e in _addresses.entries) {
      final peerId = PeerId(value: base64Decode(e.key));
      for (final address in e.value) {
        addPeerAddress(
          canForward: true, // Bootstrap nodes can forward messages.
          peerId: peerId,
          address: FullAddress(address: address, port: port),
          properties: addressProperties,
        );
      }
    }

    // Restart the router after adding the bootstrap node to establish
    // connections.
    await start();
  }

  /// Removes all bootstrap nodes from the router.
  ///
  /// This method removes all bootstrap nodes from the router's routing table
  /// and clears the internal list of bootstrap node addresses.
  void removeAllBootstraps() {
    // Iterate through the bootstrap node addresses and remove them from the
    // routing table.
    for (final e in _addresses.entries) {
      removePeerAddress(PeerId(value: base64Decode(e.key)));
    }

    // Clear the internal list of bootstrap node addresses.
    _addresses.clear();
  }
}
