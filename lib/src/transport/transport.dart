/// Provides network transport implementations for peer-to-peer communication.
///
/// This library defines abstract classes and concrete implementations for
/// network transports used in peer-to-peer communication. It includes
/// support for UDP and provides a base class for implementing other
/// transport protocols.
library transport;

// Import necessary libraries from Dart SDK.
import 'dart:io'; // Provides access to I/O operations, such as sockets and files, for network communication.
import 'dart:async'; // Provides support for asynchronous programming using Futures and Streams, essential for handling network events.

// Import libraries from the p2plib package.
import 'package:p2plib/src/data/data.dart'; // Imports data structures and models used by the library, such as PeerId and Message.


// Include separate parts of the transport implementation.
part 'transport_base.dart'; // Defines the base class for transport functionality, providing a common interface for all transport implementations.
part 'transport_udp.dart'; // Implements the transport logic for UDP, a connectionless protocol commonly used in peer-to-peer networks.
