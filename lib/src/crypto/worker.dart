import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'package:sodium/sodium.dart';

import 'package:p2plib/src/data/data.dart';

/// This function is the entry point for the crypto worker isolate.
///
/// It initializes the cryptographic engine, generates key pairs, and listens for
/// incoming cryptographic tasks from the main isolate.
///
/// This worker isolate handles cryptographic operations in a separate thread to
/// prevent blocking the main application thread. It uses the libsodium library
/// for cryptographic functions.
Future<void> cryptoWorker(dynamic initialTask) async {
  // Cast the initial task to an InitRequest to access its properties.
  initialTask as InitRequest;

  // Create a ReceivePort to receive messages from the main isolate.
  // This port acts as a communication channel between the isolates.
  final receivePort = ReceivePort();

  // Get the SendPort of the main isolate from the initial task.
  // This SendPort is used to send messages back to the main isolate.
  final mainIsolatePort = initialTask.sendPort;

  // Initialize the libsodium library.
  // This step loads the necessary cryptographic primitives for later use.
  final sodium = await SodiumInit.init(_loadSodium);

  // Get the box and sign functions from libsodium.
  // These functions are used for encryption and signing operations.
  final box = sodium.crypto.box;
  final sign = sodium.crypto.sign;

  // Generate a seed for key generation.
  // If a seed is provided in the initial task, use it.
  // Otherwise, generate a random seed using libsodium's randombytes function.
  final seed =
      initialTask.seed ?? sodium.randombytes.buf(sodium.randombytes.seedBytes);

  // Generate an encryption key pair from the seed.
  // This key pair is used for encrypting and decrypting messages.
  final encKeyPair = box.seedKeyPair(SecureKey.fromList(sodium, seed));

  // Generate a signing key pair from the seed.
  // This key pair is used for signing and verifying messages.
  final signKeyPair = sign.seedKeyPair(SecureKey.fromList(sodium, seed));

  // Send the seed, SendPort, and public keys back to the main isolate.
  // This information is needed by the main isolate to communicate with the
  // worker isolate and perform cryptographic operations.
  mainIsolatePort.send((
    seed: seed,
    sendPort: receivePort.sendPort,
    encPubKey: encKeyPair.publicKey,
    signPubKey: signKeyPair.publicKey,
  ));
// Listen for incoming tasks from the main isolate.
  receivePort.listen(
    (task) {
      // Ignore tasks that are not TaskRequest objects.
      if (task is! TaskRequest) return;

      // Handle cryptographic tasks within a try-catch block to handle errors.
      try {
        // Process the task based on its type.
        switch (task.type) {
          case TaskType.seal:
            // Create a BytesBuilder to construct the signed datagram.
            // ignore: deprecated_export_use
            final signedDatagram = BytesBuilder(copy: false)
              ..add(Message.getHeader(task.datagram));

            // If the datagram has a payload, encrypt it using the recipient's public key.
            if (Message.isNotEmptyPayload(task.datagram)) {
              signedDatagram.add(box.seal(
                publicKey: Message.getDstPeerId(task.datagram).encPublicKey,
                message: Message.getPayload(task.datagram),
              ));
            }

            // Sign the datagram using the sender's secret key.
            signedDatagram.add(sign.detached(
              message: signedDatagram.toBytes(),
              secretKey: signKeyPair.secretKey,
            ));

            // Send the signed datagram back to the main isolate.
            mainIsolatePort.send((
              id: task.id,
              datagram: signedDatagram.toBytes(),
            ));
          case TaskType.unseal:
            // Verify the signature of the datagram using the sender's public key.
            mainIsolatePort.send(sign.verifyDetached(
              message: Message.getUnsignedDatagram(task.datagram),
              signature: Message.getSignature(task.datagram),
              publicKey: Message.getSrcPeerId(task.datagram).signPiblicKey,
            )
                // If the signature is valid, proceed with unsealing.
                ? (
                    id: task.id,
                    // If the datagram has no payload, return an empty Uint8List.
                    // Otherwise, decrypt the payload using the recipient's private key.
                    datagram: Message.hasEmptyPayload(task.datagram)
                        ? emptyUint8List
                        : box.sealOpen(
                            cipherText:
                                Message.getUnsignedPayload(task.datagram),
                            publicKey: encKeyPair.publicKey,
                            secretKey: encKeyPair.secretKey,
                          )
                  )
                // If the signature is invalid, return an error.
                : (id: task.id, error: const ExceptionInvalidSignature()));
          case TaskType.verify:
            // Verify the signature of the datagram using the sender's public key.
            mainIsolatePort.send(sign.verifyDetached(
              message: Message.getUnsignedDatagram(task.datagram),
              signature: Message.getSignature(task.datagram),
              publicKey: Message.getSrcPeerId(task.datagram).signPiblicKey,
            )
                // If the signature is valid, return an empty Uint8List.
                ? (id: task.id, datagram: emptyUint8List)
                // If the signature is invalid, return an error.
                : (id: task.id, error: const ExceptionInvalidSignature()));
        }
      } catch (e) {
        // If an error occurs during processing, send the error back to the main isolate.
        mainIsolatePort.send((id: task.id, error: e));
      }
    },
    onDone: () {
      // Dispose of the secret keys when the isolate is done.
      encKeyPair.secretKey.dispose();
      signKeyPair.secretKey.dispose();
    },
    cancelOnError: false,
  );
}

/// Loads the libsodium library based on the current platform.
///
/// This function dynamically loads the libsodium library, which provides
/// cryptographic primitives, based on the operating system the application
/// is running on.
///
/// Returns a [DynamicLibrary] object representing the loaded libsodium library.
///
/// Throws an [OSError] if the current platform is not supported.
DynamicLibrary _loadSodium() {
  // Check if the platform is iOS.
  // If it is, load the library from the current process.
  if (Platform.isIOS) return DynamicLibrary.process();

  // Check if the platform is Android.
  // If it is, open the library file 'libsodium.so'.
  if (Platform.isAndroid) return DynamicLibrary.open('libsodium.so');

  // Check if the platform is Linux.
  // If it is, open the library file 'libsodium.so.23'.
  if (Platform.isLinux) return DynamicLibrary.open('libsodium.so.23');

  // Check if the platform is macOS.
  // If it is, open the library file '/usr/local/lib/libsodium.dylib'.
  if (Platform.isMacOS) {
    return DynamicLibrary.open('/usr/local/lib/libsodium.dylib');
  }

  // Check if the platform is Windows.
  // If it is, open the library file 'C:\Windows\System32\libsodium.dll'.
  if (Platform.isWindows) {
    return DynamicLibrary.open(r'C:\Windows\System32\libsodium.dll');
  }

  // If none of the above platforms are detected, throw an OSError indicating
  // that the current platform is not supported.
  throw const OSError('[Crypto] Platform not supported');
}
