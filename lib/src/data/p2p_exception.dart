part of 'data.dart';

abstract class P2PException implements Exception {
  final Object? message;
  const P2PException([this.message = '']);

  @override
  String toString() => '$runtimeType: $message';
}

class StopProcessing implements Exception {
  const StopProcessing();
}

// P2PTransport Exceptions
class P2PExceptionTransport extends P2PException {
  const P2PExceptionTransport([super.message]);
}

// P2PRouter Exceptions
class P2PExceptionRouter extends P2PException {
  const P2PExceptionRouter([super.message]);
}

class P2PExceptionIsNotRunning extends P2PExceptionRouter {
  const P2PExceptionIsNotRunning();

  @override
  String toString() => 'P2PExceptionRouter: P2PRouter is not running!';
}

class P2PExceptionUnknownRoute extends P2PExceptionRouter {
  const P2PExceptionUnknownRoute([super.message]);

  @override
  String toString() => '$runtimeType: Unknown route to $message';
}
