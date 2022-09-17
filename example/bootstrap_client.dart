import 'dart:core';
import 'dart:io';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';

const int boostrapServerPort = 4349;

Future<void> server(SendPort p) async {
  final crypto = P2PCrypto();
  await crypto.init();

  final server = BootstrapServer(
      keyPair: await crypto.signKeyPair(), port: boostrapServerPort);
  await server.run();
  return Future.value();
}

void runServer() async {
  final p = ReceivePort();
  await Isolate.spawn(server, p.sendPort);
}

main(List<String> arguments) async {
  Settings.bootstrapRegistrationTimeout = const Duration(seconds: 5);
  runServer();

  final crypto = P2PCrypto();
  await crypto.init();

  final encryptionKeyPair = await P2PCrypto().encryptionKeyPair();
  final signKeyPair = await P2PCrypto().signKeyPair();

  final router = Router(UdpConnection(ipv4Port: 4141),
      encryptionKeyPair: encryptionKeyPair,
      signKeyPair: signKeyPair,
      bootstrapServerAddress:
          // In this case, the client tries to connect to the
          // bootstrap server running locally.
          Peer(InternetAddress("127.0.0.1"), boostrapServerPort),
      bootstrapServerAddressIpv6: Peer(
          InternetAddress("::1"), boostrapServerPort));
  router.run();

  await router.bootstrapServerFinder!
      .registerMe(timeout: const Duration(seconds: 4));

  print("My network interfaces: ${router.connection.addresses}");

  final peers = await router.bootstrapServerFinder?.findPeer(router.pubKey);
  print("Lets check my ips: $peers");

  await Future.delayed(const Duration(seconds: 5));
  final fake = Peer(InternetAddress("192.168.0.1"), boostrapServerPort);
  print("set fake bootstrap");
  router.setBootstrapServer(fake, null);
  await Future.delayed(const Duration(seconds: 10));
  print("set null bootstrap");
  router.setBootstrapServer(null, null);
}
