import 'dart:io';
import 'dart:convert';
import 'package:p2plib/p2plib.dart';

void main(List<String> args) async {
  if (args.contains('help')) _printHelpScreen();
  final port = _getPort(args) ?? TransportUdp.defaultPort;
  final router = RouterL0(
    transports: [
      TransportUdp(
          bindAddress: FullAddress(
        address: InternetAddress.anyIPv4,
        port: port,
      )),
      TransportUdp(
          bindAddress: FullAddress(
        address: InternetAddress.anyIPv6,
        port: port,
      )),
    ],
  );
  if (args.contains('log')) router.logger = stdout.writeln;
  final seedS = Platform.environment['P2P_SEED'];
  final seed = await router.init(seedS == null ? null : base64Decode(seedS));
  if (args.contains('show_seed')) {
    stdout.writeln('seed: ${base64UrlEncode(seed)}');
  }
  stdout.writeln(base64UrlEncode(router.selfId.value));
  await router.start();
}

void _printHelpScreen() {
  stdout.writeln('Run with "log" parameter to write logs to stdout\n');
  stdout.writeln('Run with "show_seed" parameter to generate seed\n');
  stdout.writeln(
      '\tuse env var "P2P_SEED" to set seed or it will be generated\n');
  stdout.writeln('Run with "port [1025-65535]" parameter to set listen port\n');
  exit(0);
}

int? _getPort(List<String> args) {
  var portIndex = args.indexOf('port');
  if (portIndex > 0 && args.length > ++portIndex) {
    final port = int.tryParse(args[portIndex]) ?? 0;
    if (port < 1024 || port > 65535) {
      stdout.writeln('Error: port must be 1024-65535!');
      exit(2);
    }
    return port;
  }
  return null;
}
