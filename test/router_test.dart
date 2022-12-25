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
            completer.complete(token == Token(value: message.payload));
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
            completer.complete(token == Token(value: message.payload));
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
        'onPeerStatusChanged',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            addresses: [bobAddress],
            timestamp: DateTime.now()
                .subtract(aliceRouter.pingTimeout)
                .millisecondsSinceEpoch,
          );
          var isOnline = aliceRouter.getPeerStatus(bobRouter.selfId);
          expect(isOnline, false);

          final subscription = aliceRouter.trackPeer(
            onChange: (status) {
              isOnline = status;
            },
            peerId: bobRouter.selfId,
          );
          await Future.delayed(aliceRouter.pingPeriod * 1.5);
          expect(isOnline, true);

          bobRouter.stop();
          await Future.delayed(
            aliceRouter.pingTimeout + aliceRouter.pingPeriod,
          );
          expect(isOnline, false);
          expect(aliceRouter.getPeerStatus(bobRouter.selfId), false);
          await subscription.cancel();
        },
      );

      test(
        'onMessage gives online status',
        () async {
          await Future.wait([aliceRouter.start(), bobRouter.start()]);

          var isOnline = false;
          aliceRouter.addPeerAddress(
            peerId: bobRouter.selfId,
            addresses: [bobAddress],
            timestamp: DateTime.now()
                .subtract(aliceRouter.pingTimeout)
                .millisecondsSinceEpoch,
          );
          final subscription = aliceRouter.trackPeer(
            onChange: (status) {
              isOnline = status;
            },
            peerId: bobRouter.selfId,
          );
          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);

          await bobRouter.sendMessage(dstPeerId: aliceRouter.selfId);
          expect(isOnline, true);

          await Future.delayed(aliceRouter.pingTimeout * 1.5);
          expect(isOnline, true);

          bobRouter.stop();
          await Future.delayed(
            aliceRouter.pingTimeout + aliceRouter.pingPeriod,
          );
          expect(isOnline, false);
          expect(await aliceRouter.pingPeer(bobRouter.selfId), false);
          await subscription.cancel();
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
          await Future.wait([aliceRouter.start()]);
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
            completer.complete(token == Token(value: message.payload));
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
            completer.complete(token == Token(value: message.payload));
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
        'onPeerStatusChanged',
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
          final subscription = aliceRouter.trackPeer(
            onChange: (status) => isOnline = status,
            peerId: bobRouter.selfId,
          );
          await Future.delayed(aliceRouter.pingPeriod * 1.5);
          expect(isOnline, true);

          bobRouter.stop();
          await Future.delayed(
            aliceRouter.pingTimeout + aliceRouter.pingPeriod,
          );
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
          ]);

          var isOnline = false;
          final subscription = aliceRouter.trackPeer(
            onChange: (status) => isOnline = status,
            peerId: bobRouter.selfId,
          );
          expect(await aliceRouter.pingPeer(bobRouter.selfId), true);

          await bobRouter.sendMessage(dstPeerId: aliceRouter.selfId);
          expect(isOnline, true);

          await Future.delayed(aliceRouter.pingTimeout * 1.5);
          expect(isOnline, true);

          bobRouter.stop();
          await Future.delayed(
            aliceRouter.pingTimeout + aliceRouter.pingPeriod,
          );
          expect(isOnline, false);
          expect(await aliceRouter.pingPeer(bobRouter.selfId), false);
          await subscription.cancel();
        },
      );
    },
  );

  tearDownAll(bootstrap.kill);
  tearDown(() {
    aliceRouter.stop();
    bobRouter.stop();
    aliceRouter.clearCache();
    bobRouter.clearCache();
  });
}
