part of 'data.dart';

/// Represents properties associated with a network address.
///
/// This class encapsulates information about an address, such as:
/// - Whether it's local to the current node.
/// - Whether it's static (should not be considered stale).
/// - The last time it was seen (timestamp in milliseconds since epoch).
class AddressProperties {
  /// Creates a new instance of [AddressProperties].
  ///
  /// [isLocal] Indicates if the address is local to the current node. Defaults to `false`.
  /// [isStatic] Indicates if the address is static and should not be considered stale. Defaults to `false`.
  /// [lastSeen] The timestamp (in milliseconds since epoch) when the address was last seen.
  ///   If not provided, defaults to the current time.
  AddressProperties({
    this.isLocal = false,
    this.isStatic = false,
    int? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.timestamp().millisecondsSinceEpoch;

  /// The timestamp (in milliseconds since epoch) when the address was last seen.
  int lastSeen;

  /// Indicates whether the address is static and should not be considered stale.
  ///
  /// A static address is typically a manually configured address that is
  /// expected to be available long-term.
  bool isStatic;

  /// Indicates whether the address is local to the current node.
  ///
  /// A local address belongs to the current node itself or is within its
  /// local network.
  bool isLocal;

  /// Returns `true` if the address is not static, meaning it can be considered stale.
  ///
  /// A non-static address might be dynamically assigned or have a limited
  /// lifetime, and its availability might change over time.
  bool get isNotStatic => !isStatic;

  /// Returns `true` if the address is not local to the current node.
  ///
  /// A non-local address belongs to a remote node outside the current node's
  /// local network.
  bool get isNotLocal => !isLocal;

  /// Updates the [lastSeen] timestamp to the current time.
  ///
  /// This method is typically called when the address is observed or used,
  /// indicating its continued availability.
  void updateLastSeen() =>
      lastSeen = DateTime.timestamp().millisecondsSinceEpoch;

  /// Combines the properties of this instance with another [AddressProperties] instance.
  ///
  /// If the `other` instance has properties that are considered more relevant
  /// (e.g., it's local, static, or has a more recent `lastSeen` timestamp),
  /// those properties will be adopted by this instance.
  ///
  /// This method is used to merge information about an address from different
  /// sources, prioritizing the most up-to-date and relevant properties.
  void combine(AddressProperties other) {
    if (other.isLocal) isLocal = true;
    if (other.isStatic) isStatic = true;
    if (other.lastSeen > lastSeen) lastSeen = other.lastSeen;
  }

  /// Returns a string representation of the [AddressProperties] instance.
  ///
  /// The string includes the values of `isStatic`, `isLocal`, and `lastSeen`
  /// formatted as a human-readable description.
  @override
  String toString() => 'isStatic: $isStatic, isLocal: $isLocal, '
      'lastSeen: ${DateTime.fromMillisecondsSinceEpoch(lastSeen)}';
}
