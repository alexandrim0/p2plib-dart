part of 'data.dart';

/// Represents an immutable token.
///
/// A token is a sequence of bytes that can be used for various purposes, such as
/// authentication, authorization, or identification. This class ensures that
/// once a token is created, its value cannot be modified.
@immutable
class Token {
  /// A [ListEquality] instance for comparing lists of integers.
  ///
  /// This is used to compare the byte values of tokens for equality.
  static const _listEq = ListEquality<int>();

  /// Creates a new [Token] with the given value.
  ///
  /// [value] The byte array representing the token's value.
  const Token({required this.value});

  /// The value of the token, represented as a [Uint8List].
  final Uint8List value;

  /// Overrides the `hashCode` method to generate a hash code based on the
  /// token's value.
  ///
  /// This ensures that two tokens with the same value will have the same hash
  /// code, which is essential for using them in hash-based data structures
  /// like hash maps.
  @override
  int get hashCode => Object.hash(runtimeType, _listEq.hash(value));

  /// Overrides the `==` operator to compare two tokens for equality.
  ///
  /// Two tokens are considered equal if they have the same runtime type and
  /// their byte values are equal.
  @override
  bool operator ==(Object other) =>
      other is Token && // Check if 'other' is a Token instance.
      runtimeType == other.runtimeType && // Check if the runtime types match.
      _listEq.equals(value, other.value); // Check if the values are equal.

  /// Overrides the `toString` method to return a base64Url-encoded
  /// representation of the token's value.
  ///
  /// This provides a human-readable string representation of the token, which
  /// can be useful for debugging or display purposes.
  @override
  String toString() => base64UrlEncode(value);
}
