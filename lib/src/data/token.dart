part of 'data.dart';

class Token {
  static const _listEq = ListEquality<int>();

  final Uint8List value;

  const Token({required this.value});

  @override
  int get hashCode => Object.hash(runtimeType, _listEq.hash(value));

  @override
  bool operator ==(Object other) =>
      other is Token &&
      runtimeType == other.runtimeType &&
      _listEq.equals(value, other.value);

  String get asHex {
    final buffer = StringBuffer();
    for (final byte in value) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return '0x${buffer.toString()}';
  }

  String get asHexShort {
    final len = value.length;
    final hex = asHex;
    return len > 16
        ? '${hex.substring(0, 16)}..${hex.substring(len - 16, len)}'
        : hex;
  }

  @override
  String toString() => asHexShort;
}
