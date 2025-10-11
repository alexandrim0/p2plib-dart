import 'dart:async';
import 'dart:isolate';

import 'package:p2plib/src/data/data.dart';
import 'package:p2plib/src/crypto/worker.dart';

/// Provides cryptographic functionalities for encrypting, decrypting, signing,
/// and verifying data.
///
/// This class utilizes an isolate to perform cryptographic operations in a
/// separate thread, ensuring that the main thread is not blocked. It handles
/// key generation, sealing (encryption and signing),
/// unsealing (decryption and verification), and signature verification.
class Crypto {
  Crypto() {
    _recievePort.listen(
      _onData,
      cancelOnError: false,
    );
  }

  final _recievePort = ReceivePort();

  final _initCompleter = Completer<InitResult>();

  final Map<int, Completer<Uint8List>> _completers = {};

  late final SendPort _sendPort;

  var _idCounter = 0;

  Future<InitResult> init([Uint8List? seed]) async {
    await Isolate.spawn<Object>(
      cryptoWorker,
      (sendPort: _recievePort.sendPort, seed: seed),
      errorsAreFatal: false,
    );
    return _initCompleter.future;
  }

  Future<Uint8List> seal(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((
      id: result.id,
      type: TaskType.seal,
      datagram: datagram,
    ));
    return result.completer.future;
  }

  Future<Uint8List> unseal(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((
      id: result.id,
      type: TaskType.unseal,
      datagram: datagram,
    ));
    return result.completer.future;
  }

  Future<Uint8List> verify(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((
      id: result.id,
      type: TaskType.verify,
      datagram: datagram,
    ));
    return result.completer.future;
  }

  ({int id, Completer<Uint8List> completer}) _getCompleter() {
    final id = _idCounter++;
    final completer = Completer<Uint8List>();
    _completers[id] = completer;
    return (id: id, completer: completer);
  }

  // ignore: switch_on_type //
  void _onData(dynamic taskResult) => switch (taskResult) {
    final TaskResult r => _completers.remove(r.id)?.complete(r.datagram),
    final TaskError r => _completers.remove(r.id)?.completeError(r.error),
    final InitResponse r => () {
      _sendPort = r.sendPort;
      _initCompleter.complete((
        seed: r.seed,
        encPubKey: r.encPubKey,
        signPubKey: r.signPubKey,
      ));
    }(),
    _ => null,
  };
}
