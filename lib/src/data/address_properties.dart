part of 'data.dart';

class AddressProperties {
  int lastSeen;

  /// Defines if address can be stale or not
  bool isStatic;

  /// Defines if it needs keepalive
  bool isLocal;

  AddressProperties({
    this.isLocal = false,
    this.isStatic = false,
    int? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now().millisecondsSinceEpoch;

  bool get isNotStatic => !isStatic;

  bool get isNotLocal => !isLocal;

  void updateLastSeen() => lastSeen = DateTime.now().millisecondsSinceEpoch;

  AddressProperties combine(AddressProperties other) {
    if (other.isLocal) isLocal = true;
    if (other.isStatic) isStatic = true;
    if (other.lastSeen > lastSeen) lastSeen = other.lastSeen;
    return this;
  }

  @override
  String toString() => 'isStatic: $isStatic, isLocal: $isLocal, '
      'lastSeen: ${DateTime.fromMillisecondsSinceEpoch(lastSeen)}';
}
