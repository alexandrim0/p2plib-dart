import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '/src/data/data.dart';

import 'worker.dart';

class Crypto {
  late final CryptoKeys cryptoKeys;
  late final SendPort _sendPort;
  final _recievePort = ReceivePort();
  final Map<int, Completer<CryptoTask>> _completers = {
    0: Completer<CryptoTask>(),
  };
  var _idCounter = 0;
  var operationTimeout = const Duration(seconds: 1);

  Crypto() {
    _recievePort.listen(
      (message) {
        if (message is CryptoTask) {
          message.payload is Exception
              ? _completers.remove(message.id)?.completeError(message.payload)
              : _completers.remove(message.id)?.complete(message);
        }
      },
    );
  }

  /// Will create key pair if seed is not empty else use key pair
  Future<CryptoKeys> init([CryptoKeys? keys]) async {
    final id = _idCounter++;
    await Isolate.spawn<CryptoTask>(
      cryptoWorker,
      CryptoTask(
        id: id,
        type: CryptoTaskType.sign, // does not matter for initial task
        payload: _recievePort.sendPort,
        extra: keys,
      ),
    );
    final initResult = await _completers[id]!.future;
    _sendPort = initResult.payload as SendPort;
    cryptoKeys = initResult.extra as CryptoKeys;
    _completers.remove(id);
    return cryptoKeys;
  }

  /// Encrypt message`s payload and sign whole datagram
  Future<Uint8List> seal(final Message message) async {
    final id = _idCounter++;
    final completer = Completer<CryptoTask>();
    _completers[id] = completer;
    _sendPort.send(CryptoTask(
      id: id,
      type: CryptoTaskType.seal,
      payload: message,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is Uint8List) return result.payload as Uint8List;
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }

  /// Returns unencrypted payload of message
  Future<Uint8List> unseal(final Uint8List datagram) async {
    final id = _idCounter++;
    final completer = Completer<CryptoTask>();
    _completers[id] = completer;
    _sendPort.send(CryptoTask(
      id: id,
      type: CryptoTaskType.unseal,
      payload: datagram,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is Uint8List) return result.payload as Uint8List;
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }

  Future<Uint8List> sign(final Uint8List datagram) async {
    final id = _idCounter++;
    final completer = Completer<CryptoTask>();
    _completers[id] = completer;
    _sendPort.send(CryptoTask(
      id: id,
      type: CryptoTaskType.sign,
      payload: datagram,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is Uint8List) {
        final signed = BytesBuilder(copy: false)
          ..add(datagram)
          ..add(result.payload as Uint8List);
        return signed.toBytes();
      }
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }

  Future<bool> verifySigned(
    final Uint8List pubKey,
    final Uint8List datagram,
  ) async {
    final id = _idCounter++;
    final completer = Completer<CryptoTask>();
    _completers[id] = completer;
    _sendPort.send(CryptoTask(
      id: id,
      type: CryptoTaskType.verifySigned,
      payload: datagram,
      extra: pubKey,
    ));
    try {
      final result = await completer.future.timeout(operationTimeout);
      if (result.payload is bool) return result.payload as bool;
      throw result.payload;
    } finally {
      _completers.remove(id);
    }
  }
}
