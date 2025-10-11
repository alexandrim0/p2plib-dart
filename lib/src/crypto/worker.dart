import 'dart:io' show OSError, Platform;
import 'dart:ffi' show DynamicLibrary;
import 'dart:isolate' show ReceivePort;
import 'dart:typed_data' show BytesBuilder;
import 'package:sodium/sodium.dart';

import 'package:p2plib/src/data/data.dart';

/// This function is the entry point for the crypto worker isolate.
///
/// It initializes the cryptographic engine, generates key pairs, and listens
/// for incoming cryptographic tasks from the main isolate.
///
/// This worker isolate handles cryptographic operations in a separate thread to
/// prevent blocking the main application thread. It uses the libsodium library
/// for cryptographic functions.
Future<void> cryptoWorker(dynamic initialTask) async {
  initialTask as InitRequest;

  final receivePort = ReceivePort();
  final mainIsolatePort = initialTask.sendPort;

  final sodium = await SodiumInit.init(_loadSodium);
  final box = sodium.crypto.box;
  final sign = sodium.crypto.sign;

  final seed =
      initialTask.seed ?? sodium.randombytes.buf(sodium.randombytes.seedBytes);

  final encKeyPair = box.seedKeyPair(SecureKey.fromList(sodium, seed));
  final signKeyPair = sign.seedKeyPair(SecureKey.fromList(sodium, seed));

  mainIsolatePort.send((
    seed: seed,
    sendPort: receivePort.sendPort,
    encPubKey: encKeyPair.publicKey,
    signPubKey: signKeyPair.publicKey,
  ));

  receivePort.listen(
    (task) {
      if (task is! TaskRequest) {
        return;
      }

      try {
        switch (task.type) {
          case TaskType.seal:
            final signedDatagram = BytesBuilder(copy: false)
              ..add(Message.getHeader(task.datagram));

            if (Message.isNotEmptyPayload(task.datagram)) {
              signedDatagram.add(
                box.seal(
                  publicKey: Message.getDstPeerId(task.datagram).encPublicKey,
                  message: Message.getPayload(task.datagram),
                ),
              );
            }

            signedDatagram.add(
              sign.detached(
                message: signedDatagram.toBytes(),
                secretKey: signKeyPair.secretKey,
              ),
            );

            mainIsolatePort.send((
              id: task.id,
              datagram: signedDatagram.toBytes(),
            ));
          case TaskType.unseal:
            mainIsolatePort.send(
              sign.verifyDetached(
                    message: Message.getUnsignedDatagram(task.datagram),
                    signature: Message.getSignature(task.datagram),
                    publicKey: Message.getSrcPeerId(
                      task.datagram,
                    ).signPiblicKey,
                  )
                  ? (
                      id: task.id,
                      datagram: Message.hasEmptyPayload(task.datagram)
                          ? emptyUint8List
                          : box.sealOpen(
                              cipherText: Message.getUnsignedPayload(
                                task.datagram,
                              ),
                              publicKey: encKeyPair.publicKey,
                              secretKey: encKeyPair.secretKey,
                            ),
                    )
                  : (id: task.id, error: const ExceptionInvalidSignature()),
            );
          case TaskType.verify:
            mainIsolatePort.send(
              sign.verifyDetached(
                    message: Message.getUnsignedDatagram(task.datagram),
                    signature: Message.getSignature(task.datagram),
                    publicKey: Message.getSrcPeerId(
                      task.datagram,
                    ).signPiblicKey,
                  )
                  ? (id: task.id, datagram: emptyUint8List)
                  : (id: task.id, error: const ExceptionInvalidSignature()),
            );
        }
      } on Object catch (e) {
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
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  } else if (Platform.isAndroid) {
    return DynamicLibrary.open('libsodium.so');
  } else if (Platform.isLinux) {
    return DynamicLibrary.open('libsodium.so.23');
  } else if (Platform.isMacOS) {
    return DynamicLibrary.open('/usr/local/lib/libsodium.dylib');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open(r'C:\Windows\System32\libsodium.dll');
  } else {
    throw const OSError('[Crypto] Platform not supported');
  }
}
