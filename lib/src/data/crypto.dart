part of 'data.dart';

const sealLength = 48;

const signatureLength = 64;

typedef InitRequest = ({SendPort sendPort, Uint8List? seed});

typedef InitResponse = ({
  SendPort sendPort,
  Uint8List seed,
  Uint8List encPubKey,
  Uint8List signPubKey,
});

typedef InitResult = ({
  Uint8List seed,
  Uint8List encPubKey,
  Uint8List signPubKey,
});

typedef TaskRequest = ({int id, TaskType type, Uint8List datagram});

typedef TaskResult = ({int id, Uint8List datagram});

typedef TaskError = ({int id, Object error});

enum TaskType { seal, unseal, verify }
