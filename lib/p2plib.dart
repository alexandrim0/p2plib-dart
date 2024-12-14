/// Core library for building peer-to-peer applications.
///
/// This library provides a comprehensive set of tools and abstractions for
/// developing peer-to-peer applications in Dart. It includes functionalities
/// for data structures, cryptography, message routing, and network transport.
library p2plib;

// Export the data library.
export 'src/data/data.dart'; // Exports data structures and models used by the library, such as PeerId and Message.
// Export the crypto library.
export 'src/crypto/crypto.dart'; // Exports cryptographic functions and utilities, used for message encryption and authentication.
// Export the router library.
export 'src/router/router.dart'; // Exports the router implementation, responsible for message routing and peer discovery.
// Export the transport library.
export 'src/transport/transport.dart'; // Exports the transport layer implementations, providing communication channels for peer-to-peer interactions.
