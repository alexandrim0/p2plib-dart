import 'dart:io';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';

final bootstrapServer = Peer(InternetAddress('127.0.0.1'), 5556);

void runBootstrapServer() async {
  final p = ReceivePort();
  await Isolate.spawn(_runBootstrapServer, p.sendPort);
}

void _runBootstrapServer(SendPort p) async {
  final crypto = P2PCrypto();
  await crypto.init();

  final server = BootstrapServer(
      keyPair: await crypto.signKeyPair(), port: bootstrapServer.port);
  await server.run();
}

main(List<String> arguments) async {
  runBootstrapServer();

  final canary = Canary(port: 4040);
  canary.events.stream.asBroadcastStream().distinct().listen((event) {
    print("Event server: ${event.peer} is online: ${event.isOnline}");
  });
  canary.addServerToPing(Peer(InternetAddress("127.0.0.1"), 5556));
  await canary.run();
}
