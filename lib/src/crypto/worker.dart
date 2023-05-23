import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'package:sodium/sodium.dart';

import '/src/data/data.dart';

void cryptoWorker(initialTask) async {
  initialTask as InitRequest;
  final receivePort = ReceivePort();
  final mainIsolatePort = initialTask.sendPort;

  final sodium = await SodiumInit.init2(_loadSodium);
  final box = sodium.crypto.box;
  final sign = sodium.crypto.sign;

  final seed =
      initialTask.seed ?? sodium.randombytes.buf(sodium.randombytes.seedBytes);
  final encKeyPair = box.seedKeyPair(SecureKey.fromList(sodium, seed));
  final signKeyPair = sign.seedKeyPair(SecureKey.fromList(sodium, seed));

  // send back SendPort and keys
  mainIsolatePort.send((
    seed: seed,
    sendPort: receivePort.sendPort,
    encPubKey: encKeyPair.publicKey,
    signPubKey: signKeyPair.publicKey,
  ));

  receivePort.listen(
    (final task) {
      if (task is! TaskRequest) return;
      try {
        switch (task.type) {
          case TaskType.seal:
            // ignore: deprecated_export_use
            final signedDatagram = BytesBuilder(copy: false)
              ..add(Message.getHeader(task.datagram));
            if (Message.isNotEmptyPayload(task.datagram)) {
              signedDatagram.add(box.seal(
                publicKey: Message.getDstPeerId(task.datagram).encPublicKey,
                message: Message.getPayload(task.datagram),
              ));
            }
            signedDatagram.add(sign.detached(
              message: signedDatagram.toBytes(),
              secretKey: signKeyPair.secretKey,
            ));
            mainIsolatePort.send((
              id: task.id,
              datagram: signedDatagram.toBytes(),
            ));
            break;

          case TaskType.unseal:
            mainIsolatePort.send(sign.verifyDetached(
              message: Message.getUnsignedDatagram(task.datagram),
              signature: Message.getSignature(task.datagram),
              publicKey: Message.getSrcPeerId(task.datagram).signPiblicKey,
            )
                ? (
                    id: task.id,
                    datagram: Message.hasEmptyPayload(task.datagram)
                        ? emptyUint8List
                        : box.sealOpen(
                            cipherText:
                                Message.getUnsignedPayload(task.datagram),
                            publicKey: encKeyPair.publicKey,
                            secretKey: encKeyPair.secretKey,
                          )
                  )
                : (id: task.id, error: const ExceptionInvalidSignature()));
            break;

          case TaskType.verify:
            mainIsolatePort.send(sign.verifyDetached(
              message: Message.getUnsignedDatagram(task.datagram),
              signature: Message.getSignature(task.datagram),
              publicKey: Message.getSrcPeerId(task.datagram).signPiblicKey,
            )
                ? (id: task.id, datagram: emptyUint8List)
                : (id: task.id, error: const ExceptionInvalidSignature()));
            break;
        }
      } catch (e) {
        mainIsolatePort.send((id: task.id, error: e));
      }
    },
    onDone: () {
      encKeyPair.secretKey.dispose();
      signKeyPair.secretKey.dispose();
    },
    cancelOnError: false,
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
  throw OSError('[Crypto] Platform not supported');
}
