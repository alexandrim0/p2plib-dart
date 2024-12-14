part of 'transport.dart';

/// Base class for all transport implementations.
///
/// This class defines the common interface for sending and receiving data over
/// a network transport. It provides methods for starting and stopping the
/// transport, sending data, and handling incoming messages. Concrete transport
/// implementations, such as UDP or TCP, should extend this class and provide
/// specific implementations for the abstract methods.
abstract class TransportBase {
  /// Creates a new [TransportBase] instance.
  ///
  /// [bindAddress] The address to bind to for receiving incoming messages.
  /// [onMessage] The callback function to invoke when a message is received.
  /// [ttl] The time-to-live for outgoing packets, specifying the maximum number
  ///   of hops a packet can traverse before being discarded. Defaults to 5.
  /// [logger] A function for logging messages related to transport operations.
  TransportBase({
    required this.bindAddress,
    this.onMessage,
    this.ttl = 5,
    this.logger,
  });

  /// The address to bind to for receiving incoming messages.
  final FullAddress bindAddress;

  /// The time-to-live for outgoing packets.
  int ttl;

  /// A function for logging messages related to transport operations.
  void Function(String)? logger;

  /// The callback function to invoke when a message is received.
  Future<void> Function(Packet packet)? onMessage;

  /// Starts the transport.
  ///
  /// This method initializes the transport and starts listening for incoming
  /// messages. It should be called before sending or receiving any data.
  Future<void> start();

  /// Stops the transport.
  ///
  /// This method stops the transport and releases any resources that are being
  /// used. It should be called when the transport is no longer needed.
  void stop();

  /// Sends a datagram to one or more addresses.
  ///
  /// This method sends a datagram to the specified addresses using the
  /// underlying transport protocol. It is responsible for encoding the
  /// datagram and transmitting it over the network.
  ///
  /// [fullAddresses] An iterable of [FullAddress] objects representing the
  ///   destinations to send the datagram to.
  /// [datagram] The datagram data to be sent.
  void send(
    Iterable<FullAddress> fullAddresses,
    Uint8List datagram,
  );

  /// Returns a string representation of the bind address.
  @override
  String toString() => bindAddress.toString();
}
