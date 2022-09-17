import 'package:p2plib/p2plib.dart';

main(List<String> arguments) async {
  final crypto = P2PCrypto();
  await crypto.init();

  final server =
      BootstrapServer(keyPair: await crypto.signKeyPair(), port: 4349);
  await server.run();
}
