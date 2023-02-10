import 'dart:io';
import 'dart:convert';
import 'package:p2plib/p2plib.dart';

void main(List<String> args) async {
  if (args.contains('help')) _printHelpScreen();
  final port = _getPort(args) ?? P2PUdpTransport.defaultPort;
  final router = P2PRouterL0(
    transports: [
      P2PUdpTransport(
          bindAddress: P2PFullAddress(
        address: InternetAddress.anyIPv4,
        isLocal: false,
        port: port,
      )),
      P2PUdpTransport(
          bindAddress: P2PFullAddress(
        address: InternetAddress.anyIPv6,
        isLocal: false,
        port: port,
      )),
    ],
  );
  if (args.contains('log')) router.logger = stdout.writeln;
  final seed = Platform.environment['P2P_SEED'];
  final keys = await router.init(
    seed == null ? null : (P2PCryptoKeys.empty()..seed = base64Decode(seed)),
  );
  if (args.contains('show_seed')) {
    stdout.writeln('seed: ${base64UrlEncode(keys.seed)}');
  }
  stdout.writeln(base64UrlEncode(P2PPeerId.fromKeys(
    encryptionKey: keys.encPublicKey,
    signKey: keys.signPublicKey,
  ).value));
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
