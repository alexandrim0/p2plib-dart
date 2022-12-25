import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:sodium/sodium.dart';

import '/src/data/data.dart';

void cryptoWorker(final CryptoTask initialTask) async {
  final sodium = await SodiumInit.init(_loadSodium());
  final box = sodium.crypto.box;
  final sign = sodium.crypto.sign;

  // extra is a list of [0] encSeed, [1] signSeed
  final seeds = initialTask.extra as List<Uint8List?>;
  // Init of crypto keys
  seeds[0] ??= sodium.randombytes.buf(sodium.randombytes.seedBytes);
  seeds[1] ??= sodium.randombytes.buf(sodium.randombytes.seedBytes);
  final encKeyPair = box.seedKeyPair(SecureKey.fromList(sodium, seeds[0]!));
  final signKeyPair = sign.seedKeyPair(SecureKey.fromList(sodium, seeds[1]!));

  // send back index, SendPort and keys
  final receivePort = ReceivePort();
  final mainIsolatePort = initialTask.payload as SendPort;
  initialTask.payload = receivePort.sendPort;
  initialTask.extra = CryptoKeys(
    encPublicKey: encKeyPair.publicKey,
    encSeed: seeds[0]!,
    signPublicKey: signKeyPair.publicKey,
    signSeed: seeds[1]!,
  );
  mainIsolatePort.send(initialTask);

  receivePort.listen(
    (final task) {
      task as CryptoTask;
      try {
        switch (task.type) {
          case CryptoTaskType.seal:
            final message = task.payload as P2PMessage;
            final datagram = message.payload.isEmpty
                ? message.toBytes()
                : message
                    .copyWith(
                      payload: box.seal(
                        publicKey: message.dstPeerId.encPublicKey,
                        message: message.payload,
                      ),
                    )
                    .toBytes();
            final signature = sign.detached(
              message: datagram,
              secretKey: signKeyPair.secretKey,
            );
            final signedDatagram = BytesBuilder(copy: false)
              ..add(datagram)
              ..add(signature);
            task.payload = signedDatagram.toBytes();
            break;

          case CryptoTaskType.unseal:
            final datagram = task.payload as Uint8List;
            final unsignedDatagram = datagram.sublist(
              0,
              datagram.length - P2PMessage.signatureLength,
            );
            final message = P2PMessage.fromBytes(
              unsignedDatagram,
              task.extra as P2PPacketHeader?,
            );
            if (sign.verifyDetached(
              message: unsignedDatagram,
              signature: datagram.sublist(unsignedDatagram.length),
              publicKey: message.srcPeerId.signPiblicKey,
            )) {
              if (message.payload.isEmpty) {
                task.payload = message;
              } else if (message.payload.length > P2PMessage.sealLength) {
                task.payload = message.copyWith(
                  payload: box.sealOpen(
                    cipherText: message.payload,
                    publicKey: encKeyPair.publicKey,
                    secretKey: encKeyPair.secretKey,
                  ),
                );
              }
            } else {
              task.payload = Exception('Crypto worker. Wrong signature!');
            }
            break;

          case CryptoTaskType.encrypt:
            task.payload = box.seal(
              message: task.payload as Uint8List,
              publicKey: task.extra as Uint8List,
            );
            break;

          case CryptoTaskType.decrypt:
            task.payload = box.sealOpen(
              cipherText: task.payload as Uint8List,
              publicKey: encKeyPair.publicKey,
              secretKey: encKeyPair.secretKey,
            );
            break;

          case CryptoTaskType.sign:
            final message = task.payload as Uint8List;
            final signature = sign.detached(
              message: message,
              secretKey: signKeyPair.secretKey,
            );
            final signed = BytesBuilder(copy: false)
              ..add(message)
              ..add(signature);
            task.payload = signed.toBytes();
            break;

          case CryptoTaskType.openSigned:
            final data = task.payload as Uint8List;
            final messageLength = data.length - P2PMessage.signatureLength;
            final message = data.sublist(0, messageLength);
            task.payload = sign.verifyDetached(
              message: message,
              signature: data.sublist(messageLength),
              publicKey: task.extra as Uint8List,
            )
                ? message
                : Exception('Crypto worker. Wrong signature!');
            break;
        }
      } catch (e) {
        task.payload = e;
      }
      mainIsolatePort.send(task);
    },
    onDone: () {
      encKeyPair.secretKey.dispose();
      signKeyPair.secretKey.dispose();
    },
  );
}

DynamicLibrary _loadSodium() {
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.isAndroid) return DynamicLibrary.open('libsodium.so');
  if (Platform.isLinux) return DynamicLibrary.open('libsodium.so.23');
  if (Platform.isMacOS) {
    return DynamicLibrary.open('/usr/local/lib/libsodium.dylib');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('C:\\Windows\\System32\\libsodium.dll');
  }
  throw OSError('[P2PCrypto] Platform not supported');
}
