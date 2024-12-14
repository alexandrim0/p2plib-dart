part of 'data.dart';

/// Base class for all exceptions thrown by this library.
///
/// Provides a consistent interface for handling exceptions, including an optional
/// message for providing context. This abstract class is intended to be extended
/// by specific exception types within the library.
abstract class ExceptionBase implements Exception {
  /// Creates a new [ExceptionBase] instance.
  ///
  /// [message] An optional message describing the exception. Defaults to an
  /// empty string.
  const ExceptionBase([this.message = '']);

  /// An optional message describing the exception.
  final Object? message;

  /// Returns a string representation of the exception.
  ///
  /// The string representation includes the exception type and the optional
  /// message. This is useful for debugging and logging purposes.
  @override
  String toString() => '$runtimeType: $message';
}

/// Exception indicating that processing should be stopped immediately.
///
/// This exception is typically thrown when an unrecoverable error occurs or
/// when a specific condition requires processing to halt. It signals a critical
/// error or a deliberate interruption of the processing flow.
class StopProcessing extends ExceptionBase {
  /// Creates a new [StopProcessing] instance.
  ///
  /// [message] An optional message describing the reason for stopping
  /// processing.
  const StopProcessing([super.message]);
}

/// Exception indicating an error related to the transport layer.
///
/// This exception can be thrown for various transport-related issues, such as:
/// - Connection failures
/// - Invalid data formats
/// - Communication errors
///
/// It signifies problems with the underlying communication mechanism used by
/// the library.
class ExceptionTransport extends ExceptionBase {
  /// Creates a new [ExceptionTransport] instance.
  ///
  /// [message] An optional message describing the transport error.
  const ExceptionTransport([super.message]);
}

/// Exception indicating that an operation was attempted on a router that is not
/// currently running.
///
/// This exception is typically thrown when attempting to send or receive
/// messages while the router is not active. It indicates that the router is in
/// an invalid state for the requested operation.
class ExceptionIsNotRunning extends ExceptionBase {
  /// Creates a new [ExceptionIsNotRunning] instance.
  ///
  /// [message] An optional message describing the context of the error.
  const ExceptionIsNotRunning([super.message]);
}

/// Exception indicating that an unknown route was encountered.
///
/// This exception is typically thrown when a message is received for a
/// destination that is not registered with the router. It signifies that the
/// router does not know how to deliver the message to the intended recipient.
class ExceptionUnknownRoute extends ExceptionBase {
  /// Creates a new [ExceptionUnknownRoute] instance.
  ///
  /// [message] An optional message describing the unknown route.
  const ExceptionUnknownRoute([super.message]);
}

/// Exception indicating that an invalid signature was detected.
///
/// This exception is typically thrown during message verification when the
/// signature does not match the expected value. It indicates a potential
/// security breach or data corruption.
class ExceptionInvalidSignature extends ExceptionBase {
  /// Creates a new [ExceptionInvalidSignature] instance.
  ///
  /// [message] An optional message describing the invalid signature.
  const ExceptionInvalidSignature([super.message]);
}

/// Exception indicating that an invalid timestamp was detected.
///
/// This exception is typically thrown during message validation when the
/// timestamp is outside of the acceptable range. It might indicate a clock
/// synchronization issue or an attempt to replay an old message.
class ExceptionInvalidTimestamp extends ExceptionBase {
  /// Creates a new [ExceptionInvalidTimestamp] instance.
  ///
  /// [message] An optional message describing the invalid timestamp.
  const ExceptionInvalidTimestamp([super.message]);
}
