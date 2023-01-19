part of 'data.dart';

class P2PFullAddress {
  final InternetAddress address;
  final bool isLocal;
  final int port;

  const P2PFullAddress({
    required this.address,
    required this.port,
    required this.isLocal,
  });

  @override
  bool operator ==(Object other) =>
      other is P2PFullAddress &&
      runtimeType == other.runtimeType &&
      port == other.port &&
      address == other.address;

  @override
  int get hashCode => Object.hash(runtimeType, address, port);

  InternetAddressType get type => address.type;

  @override
  String toString() => '${address.address}:$port';
}
