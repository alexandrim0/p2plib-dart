part of 'data.dart';

/// 16 bytes - message header
/// 64 bytes - source PeerId
/// 64 bytes - destination PeerId
/// 0 | >48 bytes - encrypted payload
/// 64 bytes - signature

class P2PMessage {
  static const protocolNumber = 0;
  static const sealLength = 48;
  static const signatureLength = 64;
  static const headerLength = P2PPacketHeader.length + P2PPeerId.length * 2;
  static const emptyPayloadLength = headerLength + signatureLength;
  static const minPayloadedLength = emptyPayloadLength + sealLength;

  static const _listEq = ListEquality<int>();

  static bool hasCorrectLength(Uint8List datagram) =>
      datagram.length == emptyPayloadLength ||
      datagram.length > minPayloadedLength;

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

  static Uint8List getUnsignedDatagram(Uint8List datagram) =>
      datagram.sublist(0, datagram.length - signatureLength);

  static Uint8List getSignature(Uint8List datagram) =>
      datagram.sublist(datagram.length - signatureLength);

  static bool hasEmptyPayload(Uint8List datagram) =>
      datagram.length == emptyPayloadLength;

  static Uint8List getPayload(Uint8List datagram) =>
      datagram.sublist(headerLength, datagram.length - signatureLength);

  final P2PPacketHeader header;
  final P2PPeerId srcPeerId, dstPeerId;
  final Uint8List payload;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        header,
        srcPeerId,
        dstPeerId,
        _listEq.hash(payload),
      );

  @override
  bool operator ==(Object other) =>
      other is P2PMessage &&
      runtimeType == other.runtimeType &&
      header == other.header &&
      srcPeerId == other.srcPeerId &&
      dstPeerId == other.dstPeerId &&
      _listEq.equals(payload, other.payload);

  bool get isEmpty => payload.isEmpty;
  bool get isNotEmpty => payload.isNotEmpty;

  P2PMessage({
    required this.header,
    required this.srcPeerId,
    required this.dstPeerId,
    final Uint8List? payload,
  }) : payload = payload ?? emptyUint8List;

  factory P2PMessage.fromBytes(final Uint8List datagram) => P2PMessage(
        header: P2PPacketHeader.fromBytes(datagram),
        srcPeerId: getSrcPeerId(datagram),
        dstPeerId: getDstPeerId(datagram),
        payload: datagram.sublist(headerLength),
      );

  Uint8List toBytes() {
    final bytesBuilder = BytesBuilder(copy: false)
      ..add(header.toBytes())
      ..add(srcPeerId.value)
      ..add(dstPeerId.value)
      ..add(payload);
    return bytesBuilder.toBytes();
  }

  P2PMessage copyWith({final Uint8List? payload}) => P2PMessage(
        header: header,
        srcPeerId: srcPeerId,
        dstPeerId: dstPeerId,
        payload: payload ?? this.payload,
      );
}
