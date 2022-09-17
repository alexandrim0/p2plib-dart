import 'dart:typed_data';
import 'package:collection/collection.dart';

class RawToken {
  final Uint8List data;
  final int len;

  const RawToken({required this.data, required this.len});

  bool get isValid => data.length == len;

  @override
  String toString() => hex.substring(0, 10);

  @override
  bool operator ==(Object other) =>
      other is RawToken && IterableEquality().equals(data, other.data);

  @override
  int get hashCode => Object.hashAll(data);

  String get hex {
    final buffer = StringBuffer();
    for (int byte in data) {
      buffer.write('${byte < 16 ? '0' : ''}${byte.toRadixString(16)}');
    }
    return '0x${buffer.toString()}';
  }
}
