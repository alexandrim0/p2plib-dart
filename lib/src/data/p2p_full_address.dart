part of 'data.dart';

/// Only address and port defines hash and equality
class P2PFullAddress {
  final InternetAddress address;
  final int port;

  /// Defines if address can be stale or not
  final bool isStatic;

  /// Defines if it needs keepalive
  final bool isLocal;

  const P2PFullAddress({
    required this.address,
    required this.port,
    this.isLocal = false,
    this.isStatic = false,
  });

  @override
  bool operator ==(Object other) =>
      other is P2PFullAddress &&
      runtimeType == other.runtimeType &&
      port == other.port &&
      address == other.address;

  @override
  int get hashCode => Object.hash(runtimeType, address, port);

  bool get isNotLocal => !isLocal;
  bool get isNotStatic => !isStatic;

  InternetAddressType get type => address.type;

  @override
  String toString() =>
      '${address.address}:$port, isLocal: $isLocal, isStatic: $isStatic';
}
