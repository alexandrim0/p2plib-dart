// Import necessary libraries from the Dart SDK.
// ignore_for_file: comment_references

import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';

// Import external packages.
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';


// Export Uint8List from dart:typed_data for external use.
export 'dart:typed_data' show Uint8List;

// Include parts of this library to define its structure and components.
part 'route.dart';
part 'token.dart';
part 'crypto.dart';
part 'peer_id.dart';
part 'message.dart';
part 'packet.dart';
part 'exception.dart';
part 'full_address.dart';
part 'message_header.dart';
part 'address_properties.dart';

/// Type definition for representing the status of a peer.
///
/// Includes the peer's ID ([PeerId]) and whether it's currently online ([isOnline]).
typedef PeerStatus = ({PeerId peerId, bool isOnline});

/// An empty [Uint8List] for convenience and to avoid unnecessary allocations.
final emptyUint8List = Uint8List(0);

/// Generates a random integer using a cryptographically secure random number generator.
///
/// The generated integer is a combination of two 32-bit random numbers, 
/// providing a wider range of values.
int genRandomInt() =>
    (_random.nextInt(_maxRandomNumber) << 32) |
    _random.nextInt(_maxRandomNumber);

/// Generates a list of random bytes of the specified length.
///
/// [length] The desired length of the byte list.
///
/// Returns a [Uint8List] containing cryptographically secure random bytes.
Uint8List getRandomBytes(int length) {
  final r = Uint8List(length);
  for (var i = 0; i < length; i++) {
    r[i] = _random.nextInt(255);
  }
  return r;
}

/// The maximum value for random number generation (2^32).
///
/// This value is used to ensure that the generated random numbers 
/// are within a specific range.
const _maxRandomNumber = 1 << 32;

/// A cryptographically secure random number generator.
///
/// This generator is used to produce random values for various 
/// purposes within the library, such as generating seeds and random data.
final _random = Random.secure();
