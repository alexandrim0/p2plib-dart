// ignore_for_file: comment_references

part of 'data.dart';

/// The length of the sealed data, in bytes.
///
/// This includes the encrypted payload and authentication tag. It is a constant
/// value of 48 bytes.
const sealLength = 48;

/// The length of the digital signature used for message authentication, in bytes.
///
/// This is a constant value of 64 bytes.
const signatureLength = 64;

/// Represents a request to initialize the cryptographic engine.
///
/// This request includes:
/// - A [SendPort] for communication with the isolate.
/// - An optional [seed] for key generation. If not provided, a random seed is
///   generated.
typedef InitRequest = ({SendPort sendPort, Uint8List? seed});

/// Represents a response to an initialization request.
///
/// This response includes:
/// - The [SendPort] for communication with the isolate.
/// - The generated [seed].
/// - The encryption public key ([encPubKey]).
/// - The signing public key ([signPubKey]).
typedef InitResponse = ({
  SendPort sendPort,
  Uint8List seed,
  Uint8List encPubKey,
  Uint8List signPubKey,
});

/// Represents the result of the initialization process.
///
/// This result includes:
/// - The generated [seed].
/// - The encryption public key ([encPubKey]).
/// - The signing public key ([signPubKey]).
typedef InitResult = ({
  Uint8List seed,
  Uint8List encPubKey,
  Uint8List signPubKey,
});

/// Represents a request for a cryptographic task.
///
/// This request includes:
/// - A unique [id] for the task.
/// - The [type] of task to perform (seal, unseal, verify).
/// - The [datagram] containing the data to be processed.
typedef TaskRequest = ({int id, TaskType type, Uint8List datagram});

/// Represents the result of a cryptographic task.
///
/// This result includes:
/// - The unique [id] of the task.
/// - The resulting [datagram] containing the processed data.
typedef TaskResult = ({int id, Uint8List datagram});

/// Represents an error that occurred during a cryptographic task.
///
/// This error includes:
/// - The unique [id] of the task.
/// - The [error] object providing details about the error.
typedef TaskError = ({int id, Object error});

/// Defines the different types of cryptographic tasks that can be performed.
///
/// These tasks include:
/// - `seal`: Encrypts and authenticates a message.
/// - `unseal`: Decrypts and verifies the authenticity of a message.
/// - `verify`: Verifies the digital signature of a message.
enum TaskType { seal, unseal, verify }
