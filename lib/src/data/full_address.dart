part of 'data.dart';

class FullAddress {
  final InternetAddress address;
  final int port;

  const FullAddress({required this.address, required this.port});

  @override
  bool operator ==(Object other) =>
      other is FullAddress &&
      runtimeType == other.runtimeType &&
      port == other.port &&
      address == other.address;

  @override
  int get hashCode => Object.hash(runtimeType, address, port);

  InternetAddressType get type => address.type;

  @override
  String toString() => '${address.address}:$port';
}
