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

  @override
  String toString() => base64UrlEncode(value);
}
