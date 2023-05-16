part of 'data.dart';

/// Only address and port defines hash and equality
class FullAddress {
  const FullAddress({
    required this.address,
    required this.port,
  });

  final InternetAddress address;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is FullAddress &&
      runtimeType == other.runtimeType &&
      port == other.port &&
      address == other.address;

  @override
  int get hashCode => Object.hash(runtimeType, address, port);

  bool get isEmpty => address.rawAddress.isEmpty;

  InternetAddressType get type => address.type;

  @override
  String toString() => '${address.address}:[$port]';
}
