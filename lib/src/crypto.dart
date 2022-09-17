import 'dart:typed_data';
import 'dart:async';
import 'dart:isolate';
import 'dart:ffi';
import 'dart:io';
import 'package:sodium/sodium.dart';

class KeyPairData {
  final Uint8List pubKey;
  final Uint8List secretKey;
  const KeyPairData({required this.pubKey, required this.secretKey});
}

class P2PCrypto {
  static P2PCrypto? _instance;

  final _completers = <int, Completer>{};
  int _idCounter = 0;
  SendPort? _mainToIsolateStream;
  Isolate? _isolate;

  factory P2PCrypto() {
    _instance ??= P2PCrypto._internal();
    return _instance!;
  }
  Future<void> init() async {
    _mainToIsolateStream = await _run();
    return Future.value();
  }

  P2PCrypto._internal();

  Future<Uint8List> encrypt(
      Uint8List dstPubKey, Uint8List secretKey, Uint8List data) {
    final completer = Completer<Uint8List>();
    if (_mainToIsolateStream == null) {
      completer.completeError("Operation failed");
      return completer.future;
    }
    final msg = EncryptMsg(_idCounter++, dstPubKey, secretKey, data);
    _completers[msg.id] = completer;
    _mainToIsolateStream!.send(msg);
    return completer.future;
  }

  Future<Uint8List> decrypt(
      Uint8List srcPubKey, Uint8List secretKey, Uint8List encrypted) {
    final completer = Completer<Uint8List>();
    if (_mainToIsolateStream == null) {
      completer.completeError("Operation failed");
      return completer.future;
    }
    final msg = DecryptMsg(_idCounter++, srcPubKey, secretKey, encrypted);

    _completers[msg.id] = completer;
    _mainToIsolateStream?.send(msg);
    return completer.future;
  }

  Future<Uint8List> sign(Uint8List secretKey, Uint8List unsignedMessage) {
    final completer = Completer<Uint8List>();
    if (_mainToIsolateStream == null) {
      completer.completeError("Operation failed");
      return completer.future;
    }
    final msg = SignMsg(_idCounter++, secretKey, unsignedMessage);
    _completers[msg.id] = completer;
    _mainToIsolateStream?.send(msg);
    return completer.future;
  }

  Future<Uint8List> openSign(Uint8List pubKey, Uint8List signedData) {
    final completer = Completer<Uint8List>();
    if (_mainToIsolateStream == null) {
      completer.completeError("Operation failed");
      return completer.future;
    }
    final msg = OpenSignMsg(_idCounter++, pubKey, signedData);
    _completers[msg.id] = completer;
    _mainToIsolateStream?.send(msg);
    return completer.future;
  }

  Future<KeyPairData> encryptionKeyPair({int? seed}) {
    final completer = Completer<KeyPairData>();
    if (_mainToIsolateStream == null) {
      completer.completeError("Operation failed");
      return completer.future;
    }
    final msg = CreateEncryptionKeyPairMsg(_idCounter++, seed);
    _completers[msg.id] = completer;
    _mainToIsolateStream?.send(msg);
    return completer.future;
  }

  Future<KeyPairData> signKeyPair({int? seed}) {
    final completer = Completer<KeyPairData>();
    if (_mainToIsolateStream == null) {
      completer.completeError("Operation failed");
      return completer.future;
    }
    final msg = CreateSingKeyPairMsg(_idCounter++, seed);
    _completers[msg.id] = completer;
    _mainToIsolateStream?.send(msg);
    return completer.future;
  }

  Future<SendPort> _run() async {
    final completer = Completer<SendPort>();
    ReceivePort isolateToMainStream = ReceivePort();
    _isolate ??=
        await Isolate.spawn(_cryptoWorker, isolateToMainStream.sendPort);
    isolateToMainStream.listen((msg) {
      if (msg is SendPort) {
        completer.complete(msg);
      } else if (msg is IdData) {
        if (msg.data == null) {
          _completers[msg.id]?.completeError("Operation failed");
        } else {
          _completers[msg.id]?.complete(msg.data);
        }
      }
    });

    return completer.future;
  }

  static void _cryptoWorker(SendPort workerToMainStream) async {
    ReceivePort receivePort = ReceivePort();
    workerToMainStream.send(receivePort.sendPort);

    final libsodium = _load();
    final sodium = await SodiumInit.init(libsodium);

    receivePort.listen((msg) {
      if (msg == null) return;
      Object? data;
      try {
        if (msg is EncryptMsg) {
          data = _encrypt(sodium, msg.pubKey, msg.secretKey, msg.data);
        } else if (msg is DecryptMsg) {
          data = _decrypt(sodium, msg.pubKey, msg.secretKey, msg.data);
        } else if (msg is SignMsg) {
          data = _sign(sodium, msg.secretKey, msg.data);
        } else if (msg is OpenSignMsg) {
          data = _openSign(sodium, msg.pubKey, msg.data);
        } else if (msg is CreateEncryptionKeyPairMsg) {
          data = _createEncryptionKeyPair(sodium, seed: msg.seed);
        } else if (msg is CreateSingKeyPairMsg) {
          data = _createSignKeyPair(sodium, seed: msg.seed);
        }
        workerToMainStream.send(IdData(msg.id, data));
      } catch (_) {
        workerToMainStream.send(IdData(msg.id, null));
      }
    });
  }

  static Uint8List _encrypt(
      Sodium sodium, Uint8List dstKey, Uint8List secretKey, Uint8List data) {
    final key = SecureKey.fromList(sodium, secretKey);
    final nonce = sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);
    final encryptedData = sodium.crypto.box
        .easy(message: data, nonce: nonce, publicKey: dstKey, secretKey: key);

    final packet = BytesBuilder();
    packet.add(encryptedData);
    packet.add(nonce);
    return packet.toBytes();
  }

  static Uint8List _decrypt(Sodium sodium, Uint8List srcKey,
      Uint8List secretKey, Uint8List encrypted) {
    final key = SecureKey.fromList(sodium, secretKey);
    final int nonceStart =
        encrypted.length - sodium.crypto.secretBox.nonceBytes;
    final data = encrypted.sublist(0, nonceStart);
    final nonce = encrypted.sublist(nonceStart);

    final dectyptedData = sodium.crypto.box.openEasy(
        cipherText: data, nonce: nonce, publicKey: srcKey, secretKey: key);
    return dectyptedData;
  }

  static Uint8List _sign(
      Sodium sodium, Uint8List secretKey, Uint8List unsignedMessage) {
    final key = SecureKey.fromList(sodium, secretKey);
    return sodium.crypto.sign.call(message: unsignedMessage, secretKey: key);
  }

  static Uint8List _openSign(
      Sodium sodium, Uint8List pubKey, Uint8List signedData) {
    return sodium.crypto.sign
        .open(signedMessage: signedData, publicKey: pubKey);
  }

  static KeyPairData _createEncryptionKeyPair(Sodium sodium, {int? seed}) {
    KeyPair keypair;
    if (seed == null) {
      keypair = sodium.crypto.box.keyPair();
    } else {
      final seedKP =
          SecureKey.fromList(sodium, Uint8List.fromList(List.filled(32, seed)));
      keypair = sodium.crypto.box.seedKeyPair(seedKP);
    }
    return KeyPairData(
        pubKey: keypair.publicKey, secretKey: keypair.secretKey.extractBytes());
  }

  static KeyPairData _createSignKeyPair(Sodium sodium, {int? seed}) {
    KeyPair keypair;
    if (seed == null) {
      keypair = sodium.crypto.sign.keyPair();
    } else {
      final seedKP =
          SecureKey.fromList(sodium, Uint8List.fromList(List.filled(32, seed)));
      keypair = sodium.crypto.sign.seedKeyPair(seedKP);
    }
    return KeyPairData(
        pubKey: keypair.publicKey, secretKey: keypair.secretKey.extractBytes());
  }
}

class IdData {
  final int id;
  final dynamic data;
  const IdData(this.id, this.data);
}

class CreateEncryptionKeyPairMsg {
  final int id;
  final int? seed;
  const CreateEncryptionKeyPairMsg(this.id, this.seed);
}

class CreateSingKeyPairMsg {
  final int id;
  final int? seed;
  const CreateSingKeyPairMsg(this.id, this.seed);
}

class EncryptMsg {
  final int id;
  final Uint8List pubKey;
  final Uint8List secretKey;
  final Uint8List data;
  const EncryptMsg(this.id, this.pubKey, this.secretKey, this.data);
}

class DecryptMsg {
  final int id;
  final Uint8List pubKey;
  final Uint8List secretKey;
  final Uint8List data;
  const DecryptMsg(this.id, this.pubKey, this.secretKey, this.data);
}

class SignMsg {
  final int id;
  final Uint8List secretKey;
  final Uint8List data;
  const SignMsg(this.id, this.secretKey, this.data);
}

class OpenSignMsg {
  final int id;
  final Uint8List pubKey;
  final Uint8List data;
  const OpenSignMsg(this.id, this.pubKey, this.data);
}

/// workaround from flutter_sodium
DynamicLibrary _load() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libsodium.so');
  }
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    return DynamicLibrary.open('/usr/local/lib/libsodium.dylib');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libsodium.so.23');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('C:\\Windows\\System32\\libsodium.dll');
  }
  throw P2PCryptoPlatformNotSupported;
}

class P2PCryptoPlatformNotSupported implements Exception {
  static const description = '[P2PCrypto] Platform not supported';
}
