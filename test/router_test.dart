import 'dart:async';
import 'package:test/test.dart';

import 'mock.dart';

main() async {
  final bootstrap = await createProxy(
    address: proxyAddress,
    debugLabel: 'Bootstrap',
  );
  final aliceRouter = await createRouter(
    address: aliceAddress,
    debugLabel: 'Alice',
  );
  final bobRouter = await createRouter(
    address: bobAddress,
    debugLabel: 'Bob',
  );
  final subscription = bobRouter.messageStream.listen(null);

  group(
    'Without bootstrap server',
    () {
      test(
        'Send packet to unknown host',
        () {
          expect(
            () async => await bobRouter.sendMessage(
              isConfirmable: true,
              dstPeerId: randomPeerId,
            ),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'Send packets to known hosts, no ack',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            addresses: [bobAddress],
          );
          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == P2PToken(value: message.payload));
          });
          await aliceRouter.sendMessage(
            dstPeerId: bobRouter.selfId,
            payload: token.value,
          );
          expect(completer.isCompleted || await completer.future, true);
          subscription.onData(null);
        },
      );

      test(
        'Send packets to known hosts with ack',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            addresses: [bobAddress],
          );
          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == P2PToken(value: message.payload));
          });
          await aliceRouter.sendMessage(
            isConfirmable: true,
            dstPeerId: bobRouter.selfId,
            payload: token.value,
          );
          expect(completer.isCompleted || await completer.future, true);
          subscription.onData(null);
        },
      );

      test(
        'getPeerStatus',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);

          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            addresses: [bobAddress],
          );
          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
        },
      );

      test(
        'trackPeer',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            addresses: [bobAddress],
            timestamp: DateTime.now()
                .subtract(aliceRouter.requestTimeout)
                .millisecondsSinceEpoch,
          );
          var isOnline = aliceRouter.getPeerStatus(bobRouter.selfId);
          expect(isOnline, false);

          final subscription = aliceRouter.lastSeenStream
              .where((e) => e.key == bobRouter.selfId)
              .listen((e) => isOnline = e.value);
          await aliceRouter.pingPeer(bobRouter.selfId);
          expect(isOnline, true);

          bobRouter.stop();
          await aliceRouter.pingPeer(bobRouter.selfId);
          await Future.delayed(aliceRouter.requestTimeout);
          expect(isOnline, false);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          await subscription.cancel();
        },
      );

      test(
        'onMessage gives online status',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            addresses: [bobAddress],
            timestamp: DateTime.now()
                .subtract(aliceRouter.requestTimeout)
                .millisecondsSinceEpoch,
          );
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);

          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), true);

          await Future.delayed(aliceRouter.requestTimeout * 1.1);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);
        },
      );
    },
  );

  group(
    'With bootstrap server',
    () {
      test(
        'Send packet to unknown host',
        () async {
          aliceRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          await aliceRouter.start();
          expect(
            () async => await aliceRouter.sendMessage(
              isConfirmable: true,
              dstPeerId: randomPeerId,
            ),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'Send packets to known hosts, no ack',
        () async {
          aliceRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          bobRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await aliceRouter.sendMessage(dstPeerId: proxyPeerId);
          await Future.delayed(initTime);
          await bobRouter.sendMessage(dstPeerId: proxyPeerId);

          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == P2PToken(value: message.payload));
          });
          await aliceRouter.sendMessage(
            dstPeerId: bobRouter.selfId,
            payload: token.value,
          );

          expect(completer.isCompleted || await completer.future, true);
          subscription.onData(null);
        },
      );

      test(
        'Send packets to known hosts with ack',
        () async {
          aliceRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          bobRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await aliceRouter.sendMessage(dstPeerId: proxyPeerId);
          await Future.delayed(initTime);
          await bobRouter.sendMessage(dstPeerId: proxyPeerId);

          final completer = Completer<bool>();
          subscription.onData((message) {
            completer.complete(token == P2PToken(value: message.payload));
          });
          await aliceRouter.sendMessage(
            isConfirmable: true,
            dstPeerId: bobRouter.selfId,
            payload: token.value,
          );

          expect(completer.isCompleted || await completer.future, true);
          subscription.onData(null);
        },
      );

      test(
        'getPeerStatus',
        () async {
          aliceRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          bobRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await Future.wait([
            aliceRouter.sendMessage(dstPeerId: proxyPeerId),
            bobRouter.sendMessage(dstPeerId: proxyPeerId),
          ]);

          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
        },
      );

      test(
        'trackPeer',
        () async {
          aliceRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          bobRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
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
          await aliceRouter.pingPeer(bobRouter.selfId);
          expect(isOnline, true);

          bobRouter.stop();
          await aliceRouter.pingPeer(bobRouter.selfId);
          await Future.delayed(aliceRouter.requestTimeout);

          expect(isOnline, false);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          await subscription.cancel();
        },
      );

      test(
        'onMessage gives online status',
        () async {
          aliceRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          bobRouter.addPeerAddress(
            peerId: proxyPeerId,
            addresses: proxyAddresses,
          );
          await Future.wait([aliceRouter.start(), bobRouter.start()]);
          await Future.wait([
            aliceRouter.sendMessage(dstPeerId: proxyPeerId),
            bobRouter.sendMessage(dstPeerId: proxyPeerId),
            Future.delayed(initTime),
          ]);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);

          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), true);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), true);

          await Future.delayed(aliceRouter.requestTimeout * 1.1);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          expect(bobRouter.getPeerStatus(aliceRouter.selfId), false);
        },
      );

      // TBD:
      // test('do not forward on limit', () async {
      //   aliceRouter.addPeerAddress(
      //     peerId: proxyPeerId,
      //     addresses: proxyAddresses,
      //   );
      //   await aliceRouter.start();
      //   final message = await aliceRouter.sendMessage(dstPeerId: proxyPeerId);
      //   final datagram = message.toBytes();
      //   aliceRouter.onMessage(P2PPacket(
      //     header: P2PPacketHeader.fromBytes(datagram),
      //     datagram: datagram,
      //   ));

      //   await bobRouter.sendMessage(dstPeerId: proxyPeerId);
      //   await Future.delayed(initTime);
      //   expect(
      //     aliceRouter.sendDatagram(
      //       addresses: bobRouter.selfAddresses,
      //       datagram: P2PPacketHeader.setForwardsCount(
      //         aliceRouter.maxForwardsCount,
      //         message.toBytes(),
      //       ),
      //     ),
      //     throwsA(isA<Exception>()),
      //   );
      // });
    },
  );

  tearDownAll(bootstrap.kill);
  tearDown(() {
    aliceRouter.stop();
    bobRouter.stop();
    aliceRouter.clearResolveCache();
    bobRouter.clearResolveCache();
  });
}
