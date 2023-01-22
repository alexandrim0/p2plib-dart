import 'dart:io';
import 'package:p2plib/p2plib.dart';

void main(List<String> args) async {
  if (args.contains('help')) _printHelpScreen();
  final port = _getPort(args) ?? P2PRouterL0.defaultPort;
  final router = P2PRouterL0(
    transports: [
      P2PUdpTransport(
          fullAddress: P2PFullAddress(
        address: InternetAddress.anyIPv4,
        isLocal: false,
        port: port,
      )),
      P2PUdpTransport(
          fullAddress: P2PFullAddress(
        address: InternetAddress.anyIPv6,
        isLocal: false,
        port: port,
      )),
    ],
  );
  if (args.contains('log')) router.logger = stdout.writeln;
  await router.init();
  await router.start();
}

void _printHelpScreen() {
  stdout.writeln('Run with "log" parameter to write logs to stdout');
  stdout.writeln('Run with "port [1025-65535]" parameter to set listen port');
  exit(0);
}

int? _getPort(List<String> args) {
  // var port = 2022;
  var portIndex = args.indexOf('port');
  if (portIndex > 0 && args.length > ++portIndex) {
    final port = int.tryParse(args[portIndex]) ?? 0;
    if (port < 1024 || port > 65535) {
      stdout.writeln('Error: port must be 1025-65535!');
      exit(2);
    }
    return port;
  }
  return null;
}
