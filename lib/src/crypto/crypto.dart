import 'dart:async';
import 'dart:isolate';

import 'package:p2plib/src/data/data.dart';
import 'package:p2plib/src/crypto/worker.dart';

/// Provides cryptographic functionalities for encrypting, decrypting, signing, and verifying data.
///
/// This class utilizes an isolate to perform cryptographic operations in a separate thread,
/// ensuring that the main thread is not blocked. It handles key generation, sealing
/// (encryption and signing), unsealing (decryption and verification), and signature verification.
class Crypto {
  /// Initializes a new instance of the [Crypto] class.
  ///
  /// Sets up a listener on the receive port to handle responses from the crypto worker isolate.
  Crypto() {
    _recievePort.listen(
      (taskResult) => switch (taskResult) {
        // If the result is a TaskResult, complete the corresponding completer with the result data.
        final TaskResult r => _completers.remove(r.id)?.complete(r.datagram),
        // If the result is a TaskError, complete the corresponding completer with the error.
        final TaskError r => _completers.remove(r.id)?.completeError(r.error),
        // If the result is an InitResponse, complete the initialization completer with the initialization data.
        final InitResponse r => () {
            _sendPort = r.sendPort;
            _initCompleter.complete((
              seed: r.seed,
              encPubKey: r.encPubKey,
              signPubKey: r.signPubKey,
            ));
          }(),
        // Ignore any other type of result.
        _ => null,
      },
      cancelOnError: false,
    );
  }

  /// The receive port used to receive messages from the crypto worker isolate.
  final _recievePort = ReceivePort();

  /// A completer that is completed when the initialization process is finished.
  final _initCompleter = Completer<InitResult>();

  /// A map of completers used to track pending cryptographic tasks.
  final Map<int, Completer<Uint8List>> _completers = {};

  /// The send port used to send messages to the crypto worker isolate.
  late final SendPort _sendPort;

  /// A counter used to generate unique IDs for cryptographic tasks.
  var _idCounter = 0;

  /// Initializes the cryptographic engine and generates key pairs.
  ///
  /// [seed] An optional seed to use for key generation. If not provided, a random seed is generated.
  ///
  /// Returns a [Future] that completes with the initialization result, containing the seed and public keys.
  Future<InitResult> init([Uint8List? seed]) async {
    // Spawn the crypto worker isolate.
    await Isolate.spawn<Object>(
      cryptoWorker,
      (sendPort: _recievePort.sendPort, seed: seed),
      errorsAreFatal: false,
    );
    // Return the future that completes when the initialization is finished.
    return _initCompleter.future;
  }

  /// Encrypts a message's payload and signs the entire datagram.
  ///
  /// [datagram] The datagram to be sealed.
  ///
  /// Returns a [Future] that completes with the sealed datagram.
  Future<Uint8List> seal(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((id: result.id, type: TaskType.seal, datagram: datagram));
    return result.completer.future;
  }

  /// Decrypts and verifies the authenticity of a sealed datagram.
  ///
  /// [datagram] The sealed datagram to be unsealed.
  ///
  /// Returns a [Future] that completes with the unencrypted payload of the message.
  Future<Uint8List> unseal(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((id: result.id, type: TaskType.unseal, datagram: datagram));
    return result.completer.future;
  }

  /// Verifies the digital signature of a datagram.
  ///
  /// [datagram] The datagram to be verified.
  ///
  /// Returns a [Future] that completes with an empty [Uint8List] if the signature is valid,
  /// otherwise completes with an error.
  Future<Uint8List> verify(Uint8List datagram) {
    // Get a new completer to track the verification task.
    final result = _getCompleter();
    // Send the verification task to the crypto worker isolate.
    _sendPort.send((id: result.id, type: TaskType.verify, datagram: datagram));
    // Return the future associated with the completer.
    return result.completer.future;
  }

  /// Creates and returns a new completer with a unique ID.
  ///
  /// This method is used to track pending cryptographic tasks.
  /// It generates a unique ID for each task and stores the completer
  /// in the `_completers` map, allowing the result to be delivered
  /// when the task is completed by the crypto worker isolate.
  ///
  /// Returns a record containing the generated ID and the new completer.
  ({int id, Completer<Uint8List> completer}) _getCompleter() {
    // Increment the ID counter to generate a unique ID.
    final id = _idCounter++;
    // Create a new completer for the task.
    final completer = Completer<Uint8List>();
    // Store the completer in the map, using the ID as the key.
    _completers[id] = completer;
    // Return the ID and completer.
    return (id: id, completer: completer);
  }
}
