import 'dart:async';
import 'package:test/test.dart';

import 'mock.dart';

main() async {
  final bootstrap = await createProxy(
    address: proxyAddressWithProperties.key,
    debugLabel: 'Bootstrap',
  );
  final aliceRouter = await createRouter(
    address: aliceAddressWithProperties.key,
    debugLabel: 'Alice',
  );
  final bobRouter = await createRouter(
    address: bobAddressWithProperties.key,
    debugLabel: 'Bob',
  );
  final subscription = bobRouter.messageStream.listen(null);
  final testTimeout = aliceRouter.messageTTL * 2;
  final testTimeoutLong = testTimeout * 2;

  group(
    'Without bootstrap server',
    () {
      test(
        'Send on router stopped',
        () {
          expect(
            bobRouter.sendMessage(dstPeerId: randomPeerId),
            throwsA(isA<ExceptionIsNotRunning>()),
          );
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'Send packet to unknown host',
        () async {
          await bobRouter.start();
          await expectLater(
            () => bobRouter.sendMessage(dstPeerId: randomPeerId),
            throwsA(isA<ExceptionUnknownRoute>()),
          );
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'Send packets to known hosts, no ack',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            address: bobAddressWithProperties.key,
            properties: bobAddressWithProperties.value,
          );
          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == Token(value: message.payload!));
          });
          await aliceRouter.sendMessage(
            dstPeerId: bobRouter.selfId,
            payload: token.value,
          );
          expect(completer.isCompleted || await completer.future, true);
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'Send packets to known hosts with ack',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            address: bobAddressWithProperties.key,
            properties: bobAddressWithProperties.value,
          );
          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == Token(value: message.payload!));
          });

          await expectLater(
            aliceRouter.sendMessage(
              isConfirmable: true,
              dstPeerId: bobRouter.selfId,
              payload: token.value,
            ),
            completes,
          );
          expect(completer.isCompleted || await completer.future, true);
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'getPeerStatus',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);

          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            address: bobAddressWithProperties.key,
            properties: bobAddressWithProperties.value,
          );
          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'trackPeer',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            address: bobAddressWithProperties.key,
            properties: AddressProperties(
              isLocal: bobAddressWithProperties.value.isLocal,
              isStatic: bobAddressWithProperties.value.isStatic,
              lastSeen: DateTime.now()
                  .subtract(aliceRouter.peerOnlineTimeout)
                  .millisecondsSinceEpoch,
            ),
          );
          var isOnline = aliceRouter.getPeerStatus(bobRouter.selfId);
          expect(isOnline, false);

          final subscription = aliceRouter.lastSeenStream
              .where((e) => e.key == bobRouter.selfId)
              .listen((e) => isOnline = e.value);

          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          await Future.delayed(initTime);
          expect(isOnline, true);

          bobRouter.stop();
          expect(await aliceRouter.pingPeer(bobRouter.selfId), false);

          await Future.delayed(aliceRouter.peerOnlineTimeout);
          expect(isOnline, false);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          await subscription.cancel();
        },
        timeout: Timeout(testTimeoutLong),
      );

      test(
        'onMessage gives online status',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            address: bobAddressWithProperties.key,
            properties: AddressProperties(
              isLocal: bobAddressWithProperties.value.isLocal,
              isStatic: bobAddressWithProperties.value.isStatic,
              lastSeen: DateTime.now()
                  .subtract(aliceRouter.peerOnlineTimeout)
                  .millisecondsSinceEpoch,
            ),
          );
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);

          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          await Future.delayed(initTime);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), true);

          await Future.delayed(aliceRouter.peerOnlineTimeout * 1.1);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);
        },
        timeout: Timeout(testTimeoutLong),
      );
    },
  );

  group(
    'With bootstrap server',
    () {
      test(
        'Send packet to unknown host',
        () async {
          aliceRouter.routes[proxyPeerId] = getProxyRoute();
          await aliceRouter.start();
          expect(
            aliceRouter.sendMessage(
              isConfirmable: true,
              dstPeerId: randomPeerId,
            ),
            throwsA(isA<TimeoutException>()),
          );
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'Send packets to known hosts, no ack',
        () async {
          final proxyRoute = getProxyRoute();
          aliceRouter.routes[proxyPeerId] = proxyRoute;
          bobRouter.routes[proxyPeerId] = proxyRoute;
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await aliceRouter.sendMessage(dstPeerId: proxyPeerId);
          await bobRouter.sendMessage(dstPeerId: proxyPeerId);
          await Future.delayed(initTime);

          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == Token(value: message.payload!));
          });
          await aliceRouter.sendMessage(
            dstPeerId: bobRouter.selfId,
            payload: token.value,
          );

          expect(completer.isCompleted || await completer.future, true);
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'Send packets to known hosts with ack',
        () async {
          final proxyRoute = getProxyRoute();
          aliceRouter.routes[proxyPeerId] = proxyRoute;
          bobRouter.routes[proxyPeerId] = proxyRoute;
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await aliceRouter.sendMessage(dstPeerId: proxyPeerId);
          await Future.delayed(initTime);
          await bobRouter.sendMessage(dstPeerId: proxyPeerId);
          await Future.delayed(initTime);

          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == Token(value: message.payload!));
          });

          await expectLater(
            aliceRouter.sendMessage(
              isConfirmable: true,
              dstPeerId: bobRouter.selfId,
              payload: token.value,
            ),
            completes,
          );
          expect(completer.isCompleted || await completer.future, true);
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'getPeerStatus',
        () async {
          final proxyRoute = getProxyRoute();
          aliceRouter.routes[proxyPeerId] = proxyRoute;
          bobRouter.routes[proxyPeerId] = proxyRoute;
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await Future.wait([
            aliceRouter.sendMessage(dstPeerId: proxyPeerId),
            bobRouter.sendMessage(dstPeerId: proxyPeerId),
          ]);

          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
        },
        timeout: Timeout(testTimeout),
      );

      test(
        'trackPeer',
        () async {
          final proxyRoute = getProxyRoute();
          aliceRouter.routes[proxyPeerId] = proxyRoute;
          bobRouter.routes[proxyPeerId] = proxyRoute;
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await Future.wait([
            aliceRouter.sendMessage(dstPeerId: proxyPeerId),
            bobRouter.sendMessage(dstPeerId: proxyPeerId),
          ]);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);

          var isOnline = false;
          final subscription = aliceRouter.lastSeenStream
              .where((e) => e.key == bobRouter.selfId)
              .listen((e) => isOnline = e.value);

          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          await Future.delayed(initTime);
          expect(isOnline, true);

          bobRouter.stop();
          await aliceRouter.pingPeer(bobRouter.selfId);
          await Future.delayed(aliceRouter.peerOnlineTimeout);

          expect(isOnline, false);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          await subscription.cancel();
        },
        timeout: Timeout(testTimeoutLong),
      );

      test(
        'onMessage gives online status',
        () async {
          final proxyRoute = getProxyRoute();
          aliceRouter.routes[proxyPeerId] = proxyRoute;
          bobRouter.routes[proxyPeerId] = proxyRoute;
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await Future.delayed(initTime);
          await aliceRouter.sendMessage(dstPeerId: proxyPeerId);
          await Future.delayed(initTime);
          await bobRouter.sendMessage(dstPeerId: proxyPeerId);

          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);

          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), true);

          await Future.delayed(aliceRouter.peerOnlineTimeout * 1.5);
          print(aliceRouter.routes);
          print(bobRouter.routes);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);
        },
        timeout: Timeout(testTimeoutLong),
      );

      test('do not forward on limit', () async {
        final proxyRoute = getProxyRoute();
        aliceRouter.routes[proxyPeerId] = proxyRoute;
        bobRouter.routes[proxyPeerId] = proxyRoute;
        await Future.wait([aliceRouter.start(), bobRouter.start()]);
        await Future.delayed(initTime);
        await aliceRouter.sendMessage(dstPeerId: proxyPeerId);
        await Future.delayed(initTime);
        await bobRouter.sendMessage(dstPeerId: proxyPeerId);
        await Future.delayed(initTime);

        final header = PacketHeader(
          messageType: PacketType.confirmable,
          issuedAt: DateTime.now().millisecondsSinceEpoch,
          id: genRandomInt(),
        );
        final datagram = await aliceRouter.crypto.seal(Message(
          header: header,
          srcPeerId: aliceRouter.selfId,
          dstPeerId: bobRouter.selfId,
        ).toBytes());

        await expectLater(
          aliceRouter.sendDatagramConfirmable(
            messageId: header.id,
            datagram: datagram,
            addresses: [proxyAddressWithProperties.key],
          ),
          completes,
        );

        final header2 = PacketHeader(
          messageType: PacketType.confirmable,
          issuedAt: DateTime.now().millisecondsSinceEpoch,
          id: genRandomInt(),
        );
        final datagram2 = await aliceRouter.crypto.seal(Message(
          header: header2,
          srcPeerId: aliceRouter.selfId,
          dstPeerId: bobRouter.selfId,
        ).toBytes());
        datagram2[0] = 2;

        await expectLater(
          aliceRouter.sendDatagramConfirmable(
            messageId: header2.id,
            datagram: datagram2,
            addresses: [proxyAddressWithProperties.key],
          ),
          throwsA(isA<TimeoutException>()),
        );
      });
    },
    timeout: Timeout(testTimeoutLong),
  );

  tearDownAll(bootstrap.kill);
  tearDown(() {
    subscription.onData(null);
    aliceRouter.stop();
    bobRouter.stop();
    aliceRouter.routes.clear();
    bobRouter.routes.clear();
  });
}
