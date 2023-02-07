part of 'data.dart';

/// 16 bytes - message header
/// 64 bytes - source PeerId
/// 64 bytes - destination PeerId
/// 0 | >48 bytes - encrypted payload
/// 64 bytes - signature

class P2PMessage {
  static const protocolNumber = 0;
  static const headerLength = P2PPacketHeader.length + P2PPeerId.length * 2;
  static const emptySignedMessageLength = headerLength + signatureLength;

  static bool hasCorrectLength(Uint8List datagram) =>
      datagram.length == emptySignedMessageLength ||
      datagram.length > emptySignedMessageLength + sealLength;

  static P2PPeerId getSrcPeerId(Uint8List datagram) => P2PPeerId(
          value: datagram.sublist(
        P2PPacketHeader.length,
        P2PPacketHeader.length + P2PPeerId.length,
      ));

  static P2PPeerId getDstPeerId(Uint8List datagram) => P2PPeerId(
          value: datagram.sublist(
        P2PPacketHeader.length + P2PPeerId.length,
        headerLength,
      ));

  static Uint8List getUnsignedDatagram(Uint8List signedDatagram) =>
      signedDatagram.sublist(0, signedDatagram.length - signatureLength);

  static Uint8List getSignature(Uint8List signedDatagram) =>
      signedDatagram.sublist(signedDatagram.length - signatureLength);

  static bool hasEmptyPayload(Uint8List signedDatagram) =>
      signedDatagram.length == emptySignedMessageLength;

  static Uint8List getPayload(Uint8List signedDatagram) => signedDatagram
      .sublist(headerLength, signedDatagram.length - signatureLength);

  final P2PPacketHeader header;
  final P2PPeerId srcPeerId, dstPeerId;
  Uint8List? payload;

  P2PMessage({
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
