part of 'data.dart';

/// Represents a full network address, including an IP address and a port number.
///
/// This class is immutable, meaning that its properties cannot be changed after
/// it is created. It encapsulates the essential information needed to identify
/// a specific network endpoint.
@immutable
class FullAddress {
  /// Creates a new [FullAddress] instance.
  ///
  /// The [address] and [port] parameters are required and represent the IP
  /// address and port number of the network endpoint, respectively.
  const FullAddress({
    required this.address,
    required this.port,
  });

  /// The IP address of this network address.
  ///
  /// This property represents the network address of the endpoint, either IPv4
  /// or IPv6.
  final InternetAddress address;

  /// The port number of this network address.
  ///
  /// This property represents the port number associated with the endpoint,
  /// used to identify a specific service or application running on the host.
  final int port;

  /// Determines whether this address is equal to another object.
  ///
  /// Two [FullAddress] instances are considered equal if they have the same IP
  /// address and port number. This method is used for comparison and equality
  /// checks.
  @override
  bool operator ==(Object other) =>
      other is FullAddress &&
      runtimeType == other.runtimeType &&
      port == other.port &&
      address == other.address;

  /// Returns the hash code for this address.
  ///
  /// The hash code is calculated based on the IP address and port number. This
  /// method is used for hashing and data structures that rely on hash codes,
  /// such as hash tables.
  @override
  int get hashCode => Object.hash(runtimeType, address, port);

  /// Returns `true` if the address is empty, meaning it has no IP address.
  ///
  /// This is typically the case for addresses that have not yet been resolved
  /// or are invalid. An empty address cannot be used for network communication.
  bool get isEmpty => address.rawAddress.isEmpty;

  /// Returns the type of IP address.
  ///
  /// This can be either [InternetAddressType.IPv4] or
  /// [InternetAddressType.IPv6], indicating the version of the IP address.
  InternetAddressType get type => address.type;

  /// Returns a string representation of this address.
  ///
  /// The string representation is in the format "IP address:port", which is a
  /// common way to represent network addresses.
  @override
  String toString() => '${address.address}:[$port]';
}
