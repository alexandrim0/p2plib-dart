import 'dart:async';
import 'dart:isolate';

import '/src/data/data.dart';

import 'worker.dart';

class P2PCrypto {
  late final P2PCryptoKeys cryptoKeys;
  late final SendPort _sendPort;
  final _recievePort = ReceivePort();
  final Map<int, Completer<P2PCryptoTask>> _completers = {
    0: Completer<P2PCryptoTask>(),
  };
  var _idCounter = 0;

  P2PCrypto() {
    _recievePort.listen(
      (message) => _completers.remove(message.id)?.complete(message),
    );
  }

  /// Will create key pair if seed is not empty else use key pair
  Future<P2PCryptoKeys> init([P2PCryptoKeys? keys]) async {
    await Isolate.spawn<P2PCryptoTask>(
      cryptoWorker,
      P2PCryptoTask(
        id: _idCounter,
        type: P2PCryptoTaskType.sign, // does not matter for initial task
        payload: _recievePort.sendPort,
        extra: keys,
      ),
    );
    final initResult = await _completers[_idCounter]!.future;
    _sendPort = initResult.payload as SendPort;
    cryptoKeys = initResult.extra as P2PCryptoKeys;
    _completers.remove(_idCounter);
    return cryptoKeys;
  }

  Future<Uint8List> seal(final P2PMessage message) async {
    _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(P2PCryptoTask(
      id: _idCounter,
      type: P2PCryptoTaskType.seal,
      payload: message,
    ));
    final result = await completer.future;
    _completers.remove(_idCounter);
    if (result.payload is Uint8List) {
      return result.payload as Uint8List;
    } else {
      throw result.payload;
    }
  }

  Future<P2PMessage> unseal(
    final Uint8List datagram, [
    final P2PPacketHeader? header,
  ]) async {
    _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(P2PCryptoTask(
      id: _idCounter,
      type: P2PCryptoTaskType.unseal,
      payload: datagram,
      extra: header,
    ));
    final result = await completer.future;
    _completers.remove(_idCounter);
    if (result.payload is P2PMessage) {
      return result.payload as P2PMessage;
    } else {
      throw result.payload;
    }
  }

  Future<Uint8List> encrypt(
    final Uint8List pubKey,
    final Uint8List data,
  ) async {
    _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(P2PCryptoTask(
      id: _idCounter,
      type: P2PCryptoTaskType.encrypt,
      payload: data,
      extra: pubKey,
    ));
    final result = await completer.future;
    _completers.remove(_idCounter);
    if (result.payload is Uint8List) {
      return result.payload as Uint8List;
    } else {
      throw result.payload;
    }
  }

  Future<Uint8List> decrypt(final Uint8List data) async {
    _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(P2PCryptoTask(
      id: _idCounter,
      type: P2PCryptoTaskType.decrypt,
      payload: data,
    ));
    final result = await completer.future;
    _completers.remove(_idCounter);
    if (result.payload is Uint8List) {
      return result.payload as Uint8List;
    } else {
      throw result.payload;
    }
  }

  Future<Uint8List> sign(final Uint8List data) async {
    _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(P2PCryptoTask(
      id: _idCounter,
      type: P2PCryptoTaskType.sign,
      payload: data,
    ));
    final result = await completer.future;
    _completers.remove(_idCounter);
    if (result.payload is Uint8List) {
      return result.payload as Uint8List;
    } else {
      throw result.payload;
    }
  }

  Future<Uint8List> openSigned(
    final Uint8List pubKey,
    final Uint8List data,
  ) async {
    _idCounter++;
    final completer = Completer<P2PCryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(P2PCryptoTask(
      id: _idCounter,
      type: P2PCryptoTaskType.openSigned,
      payload: data,
      extra: pubKey,
    ));
    final result = await completer.future;
    _completers.remove(_idCounter);
    if (result.payload is Uint8List) {
      return result.payload as Uint8List;
    } else {
      throw result.payload;
    }
  }
}
