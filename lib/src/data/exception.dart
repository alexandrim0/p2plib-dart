part of 'data.dart';

abstract class ExceptionBase implements Exception {
  final Object? message;
  const ExceptionBase([this.message = '']);

  @override
  String toString() => '$runtimeType: $message';
}

class StopProcessing extends ExceptionBase {
  const StopProcessing([super.message]);
}

class ExceptionTransport extends ExceptionBase {
  const ExceptionTransport([super.message]);
}

class ExceptionIsNotRunning extends ExceptionBase {
  const ExceptionIsNotRunning();
}

class ExceptionUnknownRoute extends ExceptionBase {
  const ExceptionUnknownRoute([super.message]);
}
