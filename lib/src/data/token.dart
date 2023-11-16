part of 'data.dart';

@immutable
class Token {
  static const _listEq = ListEquality<int>();

  const Token({required this.value});

  final Uint8List value;

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
