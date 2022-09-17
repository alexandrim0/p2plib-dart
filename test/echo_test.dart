import 'dart:core';
import 'dart:io';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';
import 'package:test/test.dart';

final bootstrapServer = Peer(InternetAddress('127.0.0.1'), 5558);

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

main() async {
  runBootstrapServer();

  final crypto = P2PCrypto();
  await crypto.init();

  late Router bobRouter;
  late Router aliceRouter;
  setUp(() async {
    final bobEncryptionKeyPair = await P2PCrypto().encryptionKeyPair();
    final bobSignKeyPair = await P2PCrypto().signKeyPair();
    bobRouter = Router(UdpConnection(ipv4Port: 5232, ipv6Port: 5233),
        encryptionKeyPair: bobEncryptionKeyPair, signKeyPair: bobSignKeyPair);
    await bobRouter.run();

    final aliceEncryptionKeyPair = await P2PCrypto().encryptionKeyPair();
    final aliceSignKeyPair = await P2PCrypto().signKeyPair();
    aliceRouter = Router(UdpConnection(ipv4Port: 5332, ipv6Port: 5333),
        encryptionKeyPair: aliceEncryptionKeyPair,
        signKeyPair: aliceSignKeyPair);
    await aliceRouter.run();
  });

  tearDown(() async {
    await aliceRouter.stop();
    await bobRouter.stop();
  });

  tearDownAll(() => exit(0));

  test('getPeerStatus with no bootstrap', () async {
    final pingBob = aliceRouter.getPeerStatus(bobRouter.pubKey);
    expect(pingBob, equals(false));

    final pingAlice = aliceRouter.getPeerStatus(aliceRouter.pubKey);
    expect(pingAlice, true);
  });

  test('getPeerStatus with bootstrap', () async {
    await aliceRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.setBootstrapServer(bootstrapServer, null);

    final pingBob = aliceRouter.getPeerStatus(bobRouter.pubKey);
    expect(pingBob, equals(false));

    bool isOnline = false;
    aliceRouter.onPeerStatusChanged((status) {
      isOnline = status;
    }, bobRouter.pubKey);

    final pingAlice = aliceRouter.getPeerStatus(aliceRouter.pubKey);
    expect(pingAlice, true);

    final asyncPing = await aliceRouter.pingPeer(bobRouter.pubKey);
    expect(asyncPing, true);

    final asyncPingMe = await aliceRouter.pingPeer(bobRouter.pubKey);
    expect(asyncPingMe, true);
    expect(isOnline, equals(true));
    expect(aliceRouter.getPeerStatus(bobRouter.pubKey), equals(true));

    await bobRouter.stop();
    await Future.delayed(Settings.offlineTimeout);
    await Future.delayed(const Duration(seconds: 1));
    expect(isOnline, equals(false));
    expect(aliceRouter.getPeerStatus(bobRouter.pubKey), equals(false));
  });

  test('onMessage gives online status', () async {
    await aliceRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.run();

    bool isOnline = false;
    aliceRouter.onPeerStatusChanged((status) {
      isOnline = status;
    }, bobRouter.pubKey);

    bool test = await bobRouter.pingPeer(aliceRouter.pubKey);
    expect(test, equals(true));

    await bobRouter.sendTo(123, aliceRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.no);
    expect(isOnline, equals(true));

    await Future.delayed(Settings.offlineTimeout + const Duration(seconds: 1));
    expect(isOnline, equals(true));

    await bobRouter.stop();
    await Future.delayed(Settings.offlineTimeout + const Duration(seconds: 1));
    expect(isOnline, equals(false));

    test = await aliceRouter.pingPeer(bobRouter.pubKey);
    expect(test, equals(false));
  });
}
