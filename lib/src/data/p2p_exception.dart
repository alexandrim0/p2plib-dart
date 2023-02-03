part of 'data.dart';

abstract class P2PException implements Exception {
  final Object? message;
  const P2PException([this.message = '']);

  @override
  String toString() => '$runtimeType: $message';
}

// P2PTransport Exceptions
class P2PExceptionTransport extends P2PException {
  const P2PExceptionTransport([super.message]);
}

// P2PRouter Exceptions
class P2PExceptionRouter extends P2PException {
  const P2PExceptionRouter([super.message]);
}

class P2PExceptionRouterIsNotRunning extends P2PExceptionRouter {
  const P2PExceptionRouterIsNotRunning();

  @override
  String toString() => 'P2PExceptionRouter: P2PRouter is not running!';
}

class P2PExceptionRouterUnknownRoute extends P2PException {
  const P2PExceptionRouterUnknownRoute([super.message]);

  @override
  String toString() => '$runtimeType: Unknown route to $message';
}
