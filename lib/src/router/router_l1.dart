part of 'router.dart';

/// Enhanced router with confirmation and keepalive features.
///
/// This class extends the functionality of `RouterL0` by implementing
/// enhanced protocol features like message confirmation and keepalive
/// mechanisms. It is suitable for use as an advanced relay node or as a base
/// class for clients that require more reliable communication.
class RouterL1 extends RouterL0 {
  RouterL1({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  }) {
    // Initializes the keepalive timer. Accessing `isActive` starts the timer.
    _keepaliveWorker.isActive;
  }

  /// The retry period for sending messages.
  ///
  /// This value determines the interval between retries when sending messages
  /// that require confirmation.
  Duration retryPeriod = const Duration(seconds: 1);

  /// A map of acknowledgement completers, keyed by message ID.
  ///
  /// This map is used to track outstanding message confirmations. When a
  /// message is sent that requires confirmation, a completer is added to
  /// this map, and it is completed when the corresponding confirmation is
  /// received.
  final _ackCompleters = <int, Completer<void>>{};

  /// A stream controller for incoming messages.
  ///
  /// This controller is used to publish incoming messages to subscribers.
  final _messageController = StreamController<Message>();

  /// A timer that periodically sends keepalive messages.
  ///
  /// This timer helps to maintain connections with peers by sending periodic
  /// keepalive messages.
  late final _keepaliveWorker = Timer.periodic(
    keepalivePeriod,
    (_) async {
      // Only send keepalive messages if the router is running and there are
      // active routes.
      if (isRunning && routes.isNotEmpty) await _pingNonLocals();
    },
  );

  /// Returns an iterable of the self addresses of this router.
  ///
  /// These addresses represent the network endpoints where this router is
  /// listening for incoming messages.
  Iterable<FullAddress> get selfAddresses =>
      transports.map((t) => t.bindAddress);

  /// Returns a stream of incoming messages.
  ///
  /// This stream can be subscribed to receive notifications of incoming
  /// messages.
  Stream<Message> get messageStream => _messageController.stream;

  /// Starts the router.
  ///
  /// This method initializes the router and starts listening for incoming
  /// messages. It also pings non-local peers to establish connections.
  @override
  Future<void> start() async {
    await super.start();
    await _pingNonLocals();
  }

  /// Stops the router.
  ///
  /// This method stops the router and cleans up any resources that are being
  /// used. It also completes any pending acknowledgements with an error to
  /// signal that the router is no longer running.
  @override
  void stop() {
    // Complete any pending acknowledgements with an error to indicate that
    // the router is stopping.
    for (final c in _ackCompleters.values) {
      c.completeError(const ExceptionIsNotRunning());
    }

    // Clear the map of acknowledgement completers to release resources.
    _ackCompleters.clear();

    // Call the superclass's stop method to perform any necessary cleanup.
    super.stop();
  }

  /// Handles incoming messages.
  ///
  /// This method is called when a new message is received. It performs the
  /// following actions:
  /// 1. Decrypts the message payload.
  /// 2. Checks if the message is a confirmation and handles it accordingly.
  /// 3. Sends a confirmation if the message is confirmable.
  /// 4. Forwards the message to the subscriber if it has a payload.
  @override
  Future<Packet> onMessage(Packet packet) async {
    // Call the superclass's onMessage method to perform basic message
    // validation and routing.
    await super.onMessage(packet);

    // Decrypt the message payload using the configured cryptography instance.
    packet.payload = await crypto.unseal(packet.datagram);

    // If the message is a confirmation, complete the corresponding
    // acknowledgement and stop processing the message.
    if (packet.header.messageType == PacketType.confirmation) {
      _ackCompleters.remove(packet.header.id)?.complete();
      // Stop processing the message since it's a confirmation.
      throw const StopProcessing();
    }

    // If the message is confirmable, send a confirmation message back to
    // the sender.
    if (packet.header.messageType == PacketType.confirmable) {
      // Send a confirmation message asynchronously without awaiting its
      // completion.
      unawaited(
        crypto
            .seal(
              Message(
                header: packet.header.copyWith(
                  messageType: PacketType.confirmation,
                ),
                srcPeerId: selfId,
                dstPeerId: packet.srcPeerId,
              ).toBytes(),
            )
            .then(
              (datagram) => sendDatagram(
                addresses: [packet.srcFullAddress],
                datagram: datagram,
              ),
            ),
      );
    }

    // If the message has a payload and there is a listener, forward the
    // message to the subscriber.
    if (packet.payload.isNotEmpty && _messageController.hasListener) {
      _messageController.add(
        Message(
          header: packet.header,
          srcPeerId: packet.srcPeerId,
          dstPeerId: packet.dstPeerId,
          payload: packet.payload,
        ),
      );
    }

    return packet;
  }

  /// Sends a message to the specified destination peer.
  ///
  /// This method sends a message to the specified destination peer, optionally
  /// requesting confirmation of delivery. It resolves the peer's addresses,
  /// creates the message, encrypts it, and sends it using the configured
  /// transports.
  ///
  /// [dstPeerId] The ID of the destination peer.
  /// [isConfirmable] Whether the message should be sent confirmably, requiring
  ///   an acknowledgement from the receiver. Defaults to `false`.
  /// [messageId] An optional message ID to use. If not provided, a random ID
  ///   is generated.
  /// [payload] The data to be sent with the message.
  /// [ackTimeout] The duration to wait for an acknowledgement before timing
  ///   out. If not specified, the default message TTL is used.
  /// [useAddresses] An optional list of addresses to use for sending the
  ///   message. If not provided, the addresses are resolved using the
  ///   `dstPeerId`.
  ///
  /// Returns the header of the sent message.
  ///
  /// Throws an [ExceptionIsNotRunning] if the router is not running.
  /// Throws an [ExceptionUnknownRoute] if the destination peer is not known
  ///   or no addresses could be resolved.
  Future<PacketHeader> sendMessage({
    required PeerId dstPeerId,
    bool isConfirmable = false,
    int? messageId,
    Uint8List? payload,
    Duration? ackTimeout,
    Iterable<FullAddress>? useAddresses,
  }) async {
    // Check if the router is running.
    if (isNotRunning) {
      throw const ExceptionIsNotRunning();
    }

    // Resolve the addresses for the destination peer.
    final addresses = useAddresses ?? resolvePeerId(dstPeerId);

    // If no addresses are found, throw an exception.
    if (addresses.isEmpty) {
      throw ExceptionUnknownRoute(dstPeerId);
    }

    // Create the message.
    final message = Message(
      header: PacketHeader(
        // Set the message type based on whether it is confirmable.
        messageType: isConfirmable
            ? PacketType.confirmable
            : PacketType.regular,
        issuedAt: _now,
        // Generate a message ID if one is not provided.
        id: messageId ?? genRandomInt(),
      ),

      srcPeerId: selfId,
      dstPeerId: dstPeerId,
      payload: payload,
    );

    // Seal the message using the crypto provider.
    final datagram = await crypto.seal(message.toBytes());

    // Send the message.
    if (isConfirmable) {
      // If the message is confirmable, send it and wait for an
      // acknowledgement.
      await sendDatagramConfirmable(
        messageId: message.header.id,
        datagram: datagram,
        addresses: addresses,
        ackTimeout: ackTimeout,
      );
    } else {
      // If the message is not confirmable, send it without waiting for an
      // acknowledgement.
      sendDatagram(addresses: addresses, datagram: datagram);
      _log('sent ${datagram.length} bytes to $addresses');
    }

    return message.header;
  }

  /// Sends a confirmable datagram and waits for an acknowledgement.
  ///
  /// This method sends a datagram to the specified addresses and waits for an
  /// acknowledgement from the receiver. It uses a completer to handle the
  /// asynchronous operation and schedules retries if the acknowledgement is
  /// not received within the specified timeout.
  ///
  /// [messageId] The ID of the message being sent. This ID is used to
  ///   correlate the message with its acknowledgement.
  /// [datagram] The datagram data to be sent.
  /// [addresses] An iterable of [FullAddress] objects representing the
  ///   destinations to send the datagram to.
  /// [ackTimeout] The duration to wait for an acknowledgement before timing
  ///   out. If not specified, the default message TTL is used.
  ///
  /// Returns a [Future] that completes when the acknowledgement is received
  /// or the timeout expires.
  Future<void> sendDatagramConfirmable({
    required int messageId,
    required Uint8List datagram,
    required Iterable<FullAddress> addresses,
    Duration? ackTimeout,
  }) {
    final completer = Completer<void>();

    _ackCompleters[messageId] = completer;

    _sendAndRetry(
      datagram: datagram,
      messageId: messageId,
      addresses: addresses,
    );

    return completer.future
        // Set a timeout for the future, using the provided ackTimeout or
        // the default message TTL.
        .timeout(ackTimeout ?? messageTTL)
        // Remove the completer from the ackCompleters map when the future
        // completes.
        .whenComplete(() => _ackCompleters.remove(messageId));
  }

  /// Sends the datagram and schedules retries if necessary.
  ///
  /// This method is called repeatedly until the acknowledgement is received
  /// or the timeout expires. It checks if the router is running and if the
  /// message is still waiting for an acknowledgement before sending the
  /// datagram and scheduling a retry.
  ///
  /// [messageId] The ID of the message being sent.
  /// [datagram] The datagram data to be sent.
  /// [addresses] An iterable of [FullAddress] objects representing the
  ///   destinations to send the datagram to.
  void _sendAndRetry({
    required int messageId,
    required Uint8List datagram,
    required Iterable<FullAddress> addresses,
  }) {
    // Check if the router is running and if the message is still waiting
    // for an acknowledgement.
    if (isRunning && _ackCompleters.containsKey(messageId)) {
      sendDatagram(addresses: addresses, datagram: datagram);

      _log('sent confirmable message, id: $messageId to $addresses');

      // Schedule a retry after the retry period.
      Future.delayed(
        retryPeriod,
        () => _sendAndRetry(
          datagram: datagram,
          messageId: messageId,
          addresses: addresses,
        ),
      );
    }
  }

  /// Pings all non-local peers.
  ///
  /// This method iterates through all known routes and sends a ping message to
  /// any non-local peers. This is used to keep track of the network topology
  /// and ensure that all peers are reachable. By periodically pinging
  /// non-local peers, the router can detect changes in the network and update
  /// its routing information accordingly.
  Future<void> _pingNonLocals() async {
    for (final route in routes.values) {
      // Get a list of all non-local addresses for this route.
      final addresses = route.addresses.entries
          // Filter out local addresses, as we only want to ping non-local peers
          .where((e) => e.value.isNotLocal)
          // Map the entries to their keys (addresses).
          .map((e) => e.key);

      // If there are any non-local addresses, send a ping message.
      if (addresses.isNotEmpty) {
        // Send a message to the peer using the resolved addresses.
        // The message type is regular, and no payload is included for a ping.
        await sendMessage(
          dstPeerId: route.peerId,
          useAddresses: addresses,
        );
      }
    }
  }
}
