import 'dart:core';

class Settings {
  static Duration defaultTimeout = const Duration(seconds: 10);
  static Duration bootstrapRegistrationTimeout = const Duration(seconds: 10);
  static Duration offlineTimeout = const Duration(seconds: 5);
  static Duration pingTimeout = const Duration(seconds: 5);

  static Duration ackResponseTimeout = defaultTimeout;
  static Duration ackRepeatTimeout = const Duration(seconds: 1);

  static bool enableBootstrapProxy = true;
  static bool enableBootstrapSearch = true;
  static bool enableDirectDataTransfer = true;
}
