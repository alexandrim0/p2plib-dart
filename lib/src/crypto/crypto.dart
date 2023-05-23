import 'dart:async';
import 'dart:isolate';

import '/src/data/data.dart';

import 'worker.dart';

class Crypto {
  final _recievePort = ReceivePort();
  final _initCompleter = Completer<InitResult>();
  final Map<int, Completer<Uint8List>> _completers = {};

  late final SendPort _sendPort;

  var _idCounter = 0;
  var operationTimeout = const Duration(seconds: 1);

  Crypto() {
    _recievePort.listen(
      (taskResult) => switch (taskResult) {
        TaskResult r => _completers.remove(r.id)?.complete(r.datagram),
        TaskError r => _completers.remove(r.id)?.completeError(r.error),
        InitResponse r => () {
            _sendPort = r.sendPort;
            _initCompleter.complete((
              seed: r.seed,
              encPubKey: r.encPubKey,
              signPubKey: r.signPubKey,
            ));
          }(),
        _ => null,
      },
      cancelOnError: false,
    );
  }

  /// Will create keys from given or generated seed
  Future<InitResult> init([Uint8List? seed]) async {
    await Isolate.spawn<Object>(
      cryptoWorker,
      (sendPort: _recievePort.sendPort, seed: seed),
      errorsAreFatal: false,
    );
    return _initCompleter.future;
  }

  /// Encrypt message`s payload and sign whole datagram
  Future<Uint8List> seal(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((id: result.id, type: TaskType.seal, datagram: datagram));
    return result.completer.future;
  }

  /// Returns unencrypted payload of message
  Future<Uint8List> unseal(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((id: result.id, type: TaskType.unseal, datagram: datagram));
    return result.completer.future;
  }

  Future<Uint8List> verify(Uint8List datagram) {
    final result = _getCompleter();
    _sendPort.send((id: result.id, type: TaskType.verify, datagram: datagram));
    return result.completer.future;
  }

  ({int id, Completer<Uint8List> completer}) _getCompleter() {
    final id = _idCounter++;
    final completer = Completer<Uint8List>();
    _completers[id] = completer;
    return (id: id, completer: completer);
  }
}
