part of 'data.dart';

/// 16 bytes - message header
/// 64 bytes - source PeerId
/// 64 bytes - destination PeerId
/// 0 | >48 bytes - encrypted payload
/// 64 bytes - signature

class Message {
  static const protocolNumber = 0;
  static const headerLength = PacketHeader.length + PeerId.length * 2;
  static const emptySignedMessageLength = headerLength + signatureLength;

  static bool hasCorrectLength(Uint8List datagram) =>
      datagram.length == emptySignedMessageLength ||
      datagram.length > emptySignedMessageLength + sealLength;

  static Uint8List getHeader(Uint8List datagram) =>
      datagram.sublist(0, headerLength);

  static PeerId getSrcPeerId(Uint8List datagram) => PeerId(
          value: datagram.sublist(
        PacketHeader.length,
        PacketHeader.length + PeerId.length,
      ));

  static PeerId getDstPeerId(Uint8List datagram) => PeerId(
          value: datagram.sublist(
        PacketHeader.length + PeerId.length,
        headerLength,
      ));

  // Unsigned Datagram methods
  static Uint8List getPayload(Uint8List datagram) =>
      datagram.sublist(headerLength);

  static bool isNotEmptyPayload(Uint8List datagram) =>
      datagram.length > headerLength;

  // Signed Datagram methods
  static Uint8List getUnsignedPayload(Uint8List signedDatagram) =>
      signedDatagram.sublist(
        headerLength,
        signedDatagram.length - signatureLength,
      );

  static Uint8List getUnsignedDatagram(Uint8List signedDatagram) =>
      signedDatagram.sublist(0, signedDatagram.length - signatureLength);

  static Uint8List getSignature(Uint8List signedDatagram) =>
      signedDatagram.sublist(signedDatagram.length - signatureLength);

  static bool hasEmptyPayload(Uint8List signedDatagram) =>
      signedDatagram.length == emptySignedMessageLength;

  final PacketHeader header;
  final PeerId srcPeerId, dstPeerId;
  Uint8List? payload;

  Message({
    required this.header,
    required this.srcPeerId,
    required this.dstPeerId,
    this.payload,
  });

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
