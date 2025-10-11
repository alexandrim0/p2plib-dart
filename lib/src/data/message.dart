part of 'data.dart';

/// Message Structure:
/// - 16 bytes: Message header (contains metadata about the message)
/// - 64 bytes: Source Peer ID (identifies the sender)
/// - 64 bytes: Destination Peer ID (identifies the recipient)
/// - 0 or >48 bytes: Encrypted payload (optional data, encrypted for security)
/// - 64 bytes: Signature (used for message authentication)
class Message {
  /// Protocol number for this message type.
  ///
  /// This value is used to identify the specific protocol or application
  /// associated with this message type.
  static const protocolNumber = 0;

  /// Length of the message header in bytes.
  ///
  /// This value represents the total size of the header section in a message.
  static const int headerLength = PacketHeader.length + PeerId.length * 2;

  /// Length of an empty signed message in bytes.
  ///
  /// This value represents the minimum size of a message, even if it does not
  /// contain any payload.
  static const int emptySignedMessageLength = headerLength + signatureLength;

  /// Checks if the datagram has the correct length for a message.
  ///
  /// A message is considered to have the correct length if it is either an
  /// empty signed message (containing only header and signature) or a signed
  /// message with a payload of at least `sealLength` bytes.
  ///
  /// [datagram] The datagram to check.
  ///
  /// Returns `true` if the datagram has the correct length, `false` otherwise.
  static bool hasCorrectLength(Uint8List datagram) =>
      datagram.length == emptySignedMessageLength ||
      datagram.length > emptySignedMessageLength + sealLength;

  /// Extracts the header from the datagram.
  ///
  /// [datagram] The datagram containing the header.
  ///
  /// Returns a [Uint8List] containing the header data.
  static Uint8List getHeader(Uint8List datagram) =>
      datagram.sublist(0, headerLength);

  /// Extracts the source Peer ID from the datagram.
  ///
  /// [datagram] The datagram containing the source Peer ID.
  ///
  /// Returns a [PeerId] representing the source of the message.
  static PeerId getSrcPeerId(Uint8List datagram) => PeerId(
    value: datagram.sublist(
      PacketHeader.length,
      PacketHeader.length + PeerId.length,
    ),
  );

  /// Extracts the destination Peer ID from the datagram.
  ///
  /// [datagram] The datagram containing the destination Peer ID.
  ///
  /// Returns a [PeerId] representing the intended recipient of the message.
  static PeerId getDstPeerId(Uint8List datagram) => PeerId(
    value: datagram.sublist(
      PacketHeader.length + PeerId.length,
      headerLength,
    ),
  );

  // Unsigned Datagram methods

  /// Extracts the payload from the datagram.
  ///
  /// [datagram] The datagram containing the payload.
  ///
  /// Returns a [Uint8List] containing the payload data.
  static Uint8List getPayload(Uint8List datagram) =>
      datagram.sublist(headerLength);

  /// Checks if the datagram has a non-empty payload.
  ///
  /// [datagram] The datagram to check.
  ///
  /// Returns `true` if the datagram has a payload, `false` otherwise.
  static bool isNotEmptyPayload(Uint8List datagram) =>
      datagram.length > headerLength;
  // Signed Datagram methods

  /// Extracts the unsigned payload from a signed datagram.
  ///
  /// [signedDatagram] The signed datagram containing the payload.
  ///
  /// Returns a [Uint8List] containing the unsigned payload data.
  static Uint8List getUnsignedPayload(Uint8List signedDatagram) =>
      signedDatagram.sublist(
        headerLength,
        signedDatagram.length - signatureLength,
      );

  /// Extracts the unsigned datagram from a signed datagram.
  ///
  /// [signedDatagram] The signed datagram containing the unsigned datagram.
  ///
  /// Returns a [Uint8List] containing the unsigned datagram data.
  static Uint8List getUnsignedDatagram(Uint8List signedDatagram) =>
      signedDatagram.sublist(0, signedDatagram.length - signatureLength);

  /// Extracts the signature from a signed datagram.
  ///
  /// [signedDatagram] The signed datagram containing the signature.
  ///
  /// Returns a [Uint8List] containing the signature data.
  static Uint8List getSignature(Uint8List signedDatagram) =>
      signedDatagram.sublist(signedDatagram.length - signatureLength);

  /// Checks if the signed datagram has an empty payload.
  ///
  /// [signedDatagram] The signed datagram to check.
  ///
  /// Returns `true` if the signed datagram has an empty payload,
  /// `false` otherwise.
  static bool hasEmptyPayload(Uint8List signedDatagram) =>
      signedDatagram.length == emptySignedMessageLength;

  Message({
    required this.header,
    required this.srcPeerId,
    required this.dstPeerId,
    this.payload,
  });

  final PacketHeader header;

  final PeerId srcPeerId;

  final PeerId dstPeerId;

  Uint8List? payload;

  bool get isEmpty => payload == null || payload!.isEmpty;

  bool get isNotEmpty => payload != null && payload!.isNotEmpty;

  Uint8List toBytes() {
    final bytesBuilder = BytesBuilder(copy: false)
      ..add(header.toBytes())
      ..add(srcPeerId.value)
      ..add(dstPeerId.value);
    if (payload != null) bytesBuilder.add(payload!);
    return bytesBuilder.toBytes();
  }
}
