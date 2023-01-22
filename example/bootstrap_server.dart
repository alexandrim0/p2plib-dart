import 'dart:io';
import 'dart:convert';
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
  final keys = await router.init(_getKeys());
  if (args.contains('show_keys')) _printKeys(keys);
  await router.start();
}

void _printHelpScreen() {
  stdout.writeln('Run with "log" parameter to write logs to stdout\n');
  stdout.writeln('Run with "show_keys" parameter to print generated keys\n');
  stdout.writeln('\tuse "ENC_PUB", "ENC_PRV", "SIGN_PUB", "SIGN_PRV" names\n');
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

P2PCryptoKeys? _getKeys() {
  final env = Platform.environment;
  final encPub = env['ENC_PUB'] ?? '';
  final encPrv = env['ENC_PRV'] ?? '';
  final signPub = env['SIGN_PUB'] ?? '';
  final signPrv = env['SIGN_PRV'] ?? '';
  return encPub.isEmpty || encPrv.isEmpty || signPub.isEmpty || signPrv.isEmpty
      ? null
      : P2PCryptoKeys(
          encPublicKey: base64Decode(encPub),
          encPrivateKey: base64Decode(encPrv),
          signPublicKey: base64Decode(signPub),
          signPrivateKey: base64Decode(signPrv),
          encSeed: emptyUint8List,
          signSeed: emptyUint8List,
        );
}

void _printKeys(P2PCryptoKeys keys) {
  stdout.writeln('Encryption public key:');
  stdout.writeln(base64UrlEncode(keys.encPublicKey));
  stdout.writeln('Encryption private key:');
  stdout.writeln(base64UrlEncode(keys.encPrivateKey));
  stdout.writeln('Sign public key:');
  stdout.writeln(base64UrlEncode(keys.signPublicKey));
  stdout.writeln('Sign private key:');
  stdout.writeln(base64UrlEncode(keys.signPrivateKey));
}
