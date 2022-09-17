import 'dart:typed_data';

class Packet {
  static const topicLength = 8;
  static const srcKeyLength = 32;
  static const minimalPacketLength = topicLength + srcKeyLength;

  static int parseTopic(Uint8List data) {
    final bytes = ByteData.view(data.buffer);
    return bytes.getUint64(0);
  }
}

class IncorrectPacketLength implements Exception {
  final String? packetTitle;

  IncorrectPacketLength(this.packetTitle);

  @override
  String toString() {
    String result = 'Wrong packet format';
    if (packetTitle != null) result = '$packetTitle: $result';
    return result;
  }
}
