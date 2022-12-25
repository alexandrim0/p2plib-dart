import 'dart:async';
import 'dart:isolate';

import '/src/data/data.dart';

import 'worker.dart';

class P2PCrypto {
  late final CryptoKeys cryptoKeys;
  late final SendPort _sendPort;
  final _recievePort = ReceivePort();
  final Map<int, Completer<CryptoTask>> _completers = {
    0: Completer<CryptoTask>(),
  };
  var _idCounter = 0;

  P2PCrypto() {
    _recievePort.listen(
      (message) => _completers.remove(message.id)?.complete(message),
    );
  }

  /// seed is Uint8List(32)
  Future<CryptoKeys> init({
    final Uint8List? seedEnc,
    final Uint8List? seedSign,
  }) async {
    await Isolate.spawn<CryptoTask>(
      cryptoWorker,
      CryptoTask(
        id: _idCounter,
        type: CryptoTaskType.sign, // does not matter for initial task
        payload: _recievePort.sendPort,
        extra: [seedEnc, seedSign],
      ),
    );
    final initResult = await _completers[_idCounter]!.future;
    _sendPort = initResult.payload as SendPort;
    cryptoKeys = initResult.extra as CryptoKeys;
    _completers.remove(_idCounter);
    return cryptoKeys;
  }

  Future<Uint8List> seal(final P2PMessage message) async {
    _idCounter++;
    final completer = Completer<CryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(CryptoTask(
      id: _idCounter,
      type: CryptoTaskType.seal,
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
    final completer = Completer<CryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(CryptoTask(
      id: _idCounter,
      type: CryptoTaskType.unseal,
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
    final completer = Completer<CryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(CryptoTask(
      id: _idCounter,
      type: CryptoTaskType.encrypt,
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
    final completer = Completer<CryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(CryptoTask(
      id: _idCounter,
      type: CryptoTaskType.decrypt,
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
    final completer = Completer<CryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(CryptoTask(
      id: _idCounter,
      type: CryptoTaskType.sign,
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
    final completer = Completer<CryptoTask>();
    _completers[_idCounter] = completer;
    _sendPort.send(CryptoTask(
      id: _idCounter,
      type: CryptoTaskType.openSigned,
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
