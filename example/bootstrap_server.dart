import 'dart:io';
import 'package:p2plib/p2plib.dart';

void main(List<String> args) async {
  if (args.contains('help')) {
    stdout.writeln('Run with "log" parameter to write logs to stdout');
    exit(0);
  }
  var port = 2022;
  var portIndex = args.indexOf('port');
  if (portIndex > 0 && args.length > ++portIndex) {
    port = int.tryParse(args[portIndex]) ?? 0;
    if (port < 1024 || port > 65535) {
      stdout.writeln('Error: port must be 1025-65535!');
      exit(2);
    }
  }
  final router = P2PRouterBase(defaultPort: port);
  if (args.contains('log')) router.logger = stdout.writeln;
  await router.init();
  await router.start();
}
