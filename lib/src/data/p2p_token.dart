part of 'data.dart';

class P2PToken {
  static const _listEq = ListEquality<int>();

  final Uint8List value;

  const P2PToken({required this.value});

  @override
  int get hashCode => Object.hash(runtimeType, _listEq.hash(value));

  @override
  bool operator ==(Object other) =>
      other is P2PToken &&
      runtimeType == other.runtimeType &&
      _listEq.equals(value, other.value);

  @override
  String toString() => base64UrlEncode(value);
}
