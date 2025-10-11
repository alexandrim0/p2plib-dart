part of 'transport.dart';

/// A UDP transport implementation.
///
/// This class provides a concrete implementation of the `TransportBase`
/// abstract class for communication over UDP. It handles the creation, binding,
/// and management of UDP sockets, as well as the sending and receiving of
/// datagrams.
class TransportUdp extends TransportBase {
  /// Creates a new [TransportUdp] instance.
  ///
  /// [bindAddress] The address to bind to for receiving incoming datagrams.
  /// [onMessage] The callback function to invoke when a datagram is received.
  /// [ttl] The time-to-live for outgoing datagrams, specifying the maximum
  ///   number of hops a datagram can traverse before being discarded.
  TransportUdp({
    required super.bindAddress,
    super.onMessage,
    super.ttl,
  });

  /// The default port to use for UDP communication.
  static const defaultPort = 2022;

  /// The underlying UDP socket.
  ///
  /// This socket is used for sending and receiving datagrams. It is
  /// initialized when the transport is started and closed when the transport
  /// is stopped.
  RawDatagramSocket? _socket;

  /// Starts the transport.
  ///
  /// This method binds the socket to the specified address and starts
  /// listening for incoming datagrams. It also sets up a listener to handle
  /// incoming data.
  @override
  Future<void> start() async {
    try {
      // Bind the socket if it hasn't been bound already.
      _socket ??= await RawDatagramSocket.bind(
        bindAddress.address,
        bindAddress.port,
        ttl: ttl,
      );

      // Start listening for incoming data.
      _socket?.listen(_onData);
    } on Object catch (e) {
      // Log any errors that occur during startup.
      logger?.call(e.toString());
    }
  }

  /// Stops the transport.
  ///
  /// This method closes the socket and releases any resources held by the
  /// transport.
  @override
  void stop() {
    _socket?.close();
    _socket = null;
  }

  /// Sends a datagram to the specified addresses.
  ///
  /// This method sends a datagram to the specified addresses using the
  /// underlying UDP socket. It iterates over the provided addresses and sends
  /// the datagram to each one, skipping empty or incompatible addresses.
  ///
  /// [fullAddresses] An iterable of [FullAddress] objects representing the
  ///   destinations to send the datagram to.
  /// [datagram] The datagram data to be sent.
  @override
  void send(
    Iterable<FullAddress> fullAddresses,
    Uint8List datagram,
  ) {
    // If the socket is not initialized, do nothing.
    if (_socket == null) {
      return;
    }

    // Iterate over the provided addresses and send the datagram to each one.
    for (final peerFullAddress in fullAddresses) {
      // Skip empty or incompatible addresses.
      if (peerFullAddress.isEmpty) {
        continue;
      }
      if (peerFullAddress.type != bindAddress.type) {
        continue;
      }

      try {
        // Send the datagram using the underlying socket.
        _socket?.send(datagram, peerFullAddress.address, peerFullAddress.port);
      } on Object catch (e) {
        // Log any errors that occur during sending.
        logger?.call(e.toString());
      }
    }
  }

  /// Handles incoming data events.
  ///
  /// This method is called when a new datagram is received on the UDP socket.
  /// It processes the datagram by parsing the header, creating a [Packet]
  /// object, and invoking the `onMessage` callback, if provided.
  ///
  /// [event] The incoming data event, which should be a [RawSocketEvent.read]
  ///   event to indicate that data is available to be read from the socket.
  Future<void> _onData(RawSocketEvent event) async {
    // Only process read events, as we are interested in incoming data.
    if (event != RawSocketEvent.read) {
      return;
    }

    // Receive the datagram from the socket.
    final datagram = _socket?.receive();

    // If the datagram is invalid (null or too short to contain a valid
    // header), do nothing.
    if (datagram == null || datagram.data.length < PacketHeader.length) {
      return;
    }

    try {
      // Process the datagram by invoking the onMessage callback, if
      // provided.
      await onMessage!(
        Packet(
          srcFullAddress: FullAddress(
            address: datagram.address,
            port: datagram.port,
          ),
          header: PacketHeader.fromBytes(datagram.data),
          datagram: datagram.data,
        ),
      );
    } on StopProcessing catch (_) {
      // Ignore StopProcessing exceptions. These are expected and indicate
      // that the message has been processed and further handling is not
      // required.
    } on Object catch (e) {
      // Log any other errors that occur during processing, such as
      // exceptions thrown by the onMessage callback.
      logger?.call(e.toString());
    }
  }
}
