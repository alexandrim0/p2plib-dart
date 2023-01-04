import 'dart:io';
import 'package:p2plib/p2plib.dart';

void main(List<String> args) async {
  if (args.contains('help')) _printHelpScreen();
  final router = P2PRouterBase(defaultPort: _getPort(args));
  if (args.contains('log')) router.logger = stdout.writeln;
  await router.init();
  await router.start();
}

void _printHelpScreen() {
  stdout.writeln('Run with "log" parameter to write logs to stdout');
  stdout.writeln('Run with "port [1025-65535]" parameter to set listen port');
  exit(0);
}

int _getPort(List<String> args) {
  var port = 2022;
  var portIndex = args.indexOf('port');
  if (portIndex > 0 && args.length > ++portIndex) {
    port = int.tryParse(args[portIndex]) ?? 0;
    if (port < 1024 || port > 65535) {
      stdout.writeln('Error: port must be 1025-65535!');
      exit(2);
    }
  }
  return port;
}
