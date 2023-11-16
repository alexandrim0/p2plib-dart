import 'package:test/test.dart';

import 'mock.dart';

Future<void> main() async {
  final crypto = Crypto();
  final initResults = await crypto.init(proxySeed);
  final emptyMessage = Message(
    header: PacketHeader(
      issuedAt: DateTime.timestamp().millisecondsSinceEpoch,
      id: genRandomInt(),
    ),
    srcPeerId: proxyPeerId,
    dstPeerId: proxyPeerId,
  );
  final notEmptyMessage = Message(
    header: emptyMessage.header,
    srcPeerId: proxyPeerId,
    dstPeerId: proxyPeerId,
    payload: randomPayload,
  );
  const stressCount = 100000;

  group(
    'Base',
    () {
      test(
        'Crypto seed',
        () => expect(
          PeerId.fromKeys(
            encryptionKey: initResults.encPubKey,
            signKey: initResults.signPubKey,
          ).toString(),
          proxyPeerId.toString(),
        ),
      );
      test(
        'Crypto seal/unseal',
        () async {
          expect(
            await crypto.unseal(await crypto.seal(notEmptyMessage.toBytes())),
            randomPayload,
          );
        },
      );

      test(
        'Crypto sign/verify',
        () async {
          expect(
            await crypto.verify(await crypto.seal(emptyMessage.toBytes())),
            Uint8List(0),
          );
        },
      );
    },
  );

  group(
    'Stress test.',
    () {
      test(
        'Crypto stress test: seal/unseal',
        () async {
          final datagram = notEmptyMessage.toBytes();
          for (var i = 0; i < stressCount; i++) {
            await crypto.unseal(await crypto.seal(datagram));
          }
        },
        timeout: const Timeout(Duration(minutes: 1)),
      );
    },
  );
}
