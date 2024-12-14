/// Core library for implementing peer-to-peer network communication.
///
/// This library provides a set of classes and functions for building
/// peer-to-peer applications using various transport protocols and
/// cryptographic algorithms. It includes functionality for message routing,
/// peer discovery, and secure communication.
library router;


// Import necessary libraries from Dart SDK.
import 'dart:io'; // Provides access to I/O operations, such as sockets and files, for network communication.
import 'dart:async'; // Provides support for asynchronous programming using Futures and Streams, essential for handling network events.
import 'dart:convert'; // Provides utilities for encoding and decoding JSON and other data formats, used for message serialization.

// Import libraries from the p2plib package.
import 'package:p2plib/src/data/data.dart'; // Imports data structures and models used by the library, such as PeerId and Message.
import 'package:p2plib/src/crypto/crypto.dart'; // Imports cryptographic functions and utilities, used for message encryption and authentication.
import 'package:p2plib/src/transport/transport.dart'; // Imports transport layer implementations for communication, such as UDP and TCP.

// Include separate parts of the router implementation.
part 'router_base.dart'; // Defines the base class for router functionality, providing common methods and properties for all router implementations.
part 'router_l0.dart'; // Implements the router logic for layer 0, responsible for basic message relaying and forwarding.
part 'router_l1.dart'; // Implements the router logic for layer 1, adding features like message confirmation and keepalive mechanisms.
part 'router_l2.dart'; // Implements the router logic for layer 2, providing a higher-level API for managing peer connections and monitoring peer status.
part 'router_l3.dart'; // Implements the router logic for layer 3, handling network address management and bootstrapping.
