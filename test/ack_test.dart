import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';
import 'package:test/test.dart';

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

main() async {
  runBootstrapServer();

  final crypto = P2PCrypto();
  await crypto.init();

  late Router bobRouter;
  late Router aliceRouter;
  setUp(() async {
    final bobEncryptionKeyPair = await P2PCrypto().encryptionKeyPair();
    final bobSignKeyPair = await P2PCrypto().signKeyPair();
    bobRouter = Router(UdpConnection(ipv4Port: 3232, ipv6Port: 3233),
        encryptionKeyPair: bobEncryptionKeyPair, signKeyPair: bobSignKeyPair);
    await bobRouter.run();

    final aliceEncryptionKeyPair = await P2PCrypto().encryptionKeyPair();
    final aliceSignKeyPair = await P2PCrypto().signKeyPair();
    aliceRouter = Router(UdpConnection(ipv4Port: 1234, ipv6Port: 4321),
        encryptionKeyPair: aliceEncryptionKeyPair,
        signKeyPair: aliceSignKeyPair);
    await aliceRouter.run();
  });

  tearDown(() async {
    await aliceRouter.stop();
    await bobRouter.stop();
  });

  tearDownAll(() => exit(0));

  test('AckTimeout', () async {
    await aliceRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.setBootstrapServer(bootstrapServer, null);
    {
      final start = DateTime.now();
      await bobRouter.sendTo(123, aliceRouter.pubKey, randomBytes(),
          encrypted: Encrypted.no, ack: Ack.required);
      final end = DateTime.now();
      final ms = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
      expect(ms, lessThan(500));
    }

    {
      final start = DateTime.now();
      await bobRouter.sendTo(123, aliceRouter.pubKey, randomBytes(),
          encrypted: Encrypted.no, ack: Ack.required);
      final end = DateTime.now();
      final ms = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
      expect(ms, lessThan(500));
    }
  });

  test('Send packet with ack required to unknown host with bootstrap',
      () async {
    await aliceRouter.setBootstrapServer(bootstrapServer, null);

    expect(() async {
      await aliceRouter.sendTo(123, bobRouter.pubKey, randomBytes(),
          encrypted: Encrypted.no, ack: Ack.required);
    }, throwsA(isA<TimeoutException>()));
  });

  test('Send packet with ack required to unknown host no bootstrap', () async {
    expect(() async {
      await bobRouter.sendTo(123, aliceRouter.pubKey, randomBytes(),
          encrypted: Encrypted.no, ack: Ack.required);
    }, throwsA(isA<TimeoutException>()));
  });

  test('Send packets to known hosts with ack', () async {
    int bobCounter = 0;
    bobRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 125) {
        bobCounter++;
      }
    });
    int aliceCounter = 0;
    aliceRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 123) {
        aliceCounter++;
      }
    });
    await aliceRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.setBootstrapServer(bootstrapServer, null);
    await Future.delayed(const Duration(seconds: 1));
    await bobRouter.sendTo(123, aliceRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.required);
    await aliceRouter.sendTo(125, bobRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.required);
    expect(aliceCounter, greaterThanOrEqualTo(1));
    expect(bobCounter, greaterThanOrEqualTo(1));
  });

  test('No ack to known host, packet counter test with bootstrap', () async {
    await aliceRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.setBootstrapServer(bootstrapServer, null);
    int packetsCounter = 0;
    bobRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 124) {
        packetsCounter++;
      }
    });
    await aliceRouter.sendTo(124, bobRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.no);
    await Future.delayed(const Duration(seconds: 1));
    expect(packetsCounter, greaterThanOrEqualTo(1));
  });

  test('No ack to known host, packet counter test with bootstrap (reverse)',
      () async {
    await aliceRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.setBootstrapServer(bootstrapServer, null);
    int packetsCounter = 0;
    aliceRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 125) {
        packetsCounter++;
      }
    });
    await bobRouter.sendTo(125, aliceRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.no);
    await Future.delayed(const Duration(seconds: 1));
    expect(packetsCounter, greaterThanOrEqualTo(1));
  });

  test('No ack to myself, no bootstrap', () async {
    // alice to alice
    int packetsCounter = 0;
    aliceRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 125) {
        packetsCounter++;
      }
    });
    await aliceRouter.sendTo(125, aliceRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.no);
    await Future.delayed(const Duration(seconds: 1));
    expect(packetsCounter, greaterThanOrEqualTo(1));
    // bob to bob
    packetsCounter = 0;
    bobRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 124) {
        packetsCounter++;
      }
    });
    await bobRouter.sendTo(124, bobRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.no);
    await Future.delayed(const Duration(seconds: 1));
    expect(packetsCounter, greaterThanOrEqualTo(1));
  });

  test('No ack to myself, with bootstrap', () async {
    await aliceRouter.setBootstrapServer(bootstrapServer, null);
    await bobRouter.setBootstrapServer(bootstrapServer, null);

    // alice to alice
    int packetsCounter = 0;
    aliceRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 125) {
        packetsCounter++;
      }
    });
    await aliceRouter.sendTo(125, aliceRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.no);
    await Future.delayed(const Duration(seconds: 1));
    expect(packetsCounter, greaterThanOrEqualTo(1));
    // bob to bob
    packetsCounter = 0;
    bobRouter.p2pPackets.stream.asBroadcastStream().listen((event) {
      if (event.header.topic == 124) {
        packetsCounter++;
      }
    });
    await bobRouter.sendTo(124, bobRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.no);
    await Future.delayed(const Duration(seconds: 1));
    expect(packetsCounter, greaterThanOrEqualTo(1));
  });
}
