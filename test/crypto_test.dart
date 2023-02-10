import 'package:test/test.dart';

import 'mock.dart';

main() async {
  final crypto = Crypto();
  await crypto.init(CryptoKeys.empty()..seed = proxySeed);
  final encPublicKey = crypto.cryptoKeys.encPublicKey;
  final signPublicKey = crypto.cryptoKeys.signPublicKey;
  final emptyMessage = Message(
    header: PacketHeader(
      issuedAt: DateTime.now().millisecondsSinceEpoch,
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
            encryptionKey: encPublicKey,
            signKey: signPublicKey,
          ).toString(),
          proxyPeerId.toString(),
        ),
      );
      test(
        'Crypto seal/unseal',
        () async {
          // empty message
          expect(
            await crypto.unseal(await crypto.seal(emptyMessage)),
            emptyUint8List,
          );
          // not empty message
          expect(
            await crypto.unseal(await crypto.seal(notEmptyMessage)),
            randomPayload,
          );
        },
      );

      test(
        'Crypto sign/unsign',
        () async {
          expect(
            await crypto.verifySigned(
              signPublicKey,
              await crypto.sign(randomPayload),
            ),
            true,
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
          for (var i = 0; i < stressCount; i++) {
            await crypto.unseal(await crypto.seal(notEmptyMessage));
          }
        },
        timeout: Timeout(Duration(minutes: 1)),
      );

      test(
        'Crypto stress test: sign/unsign',
        () async {
          for (var i = 0; i < stressCount; i++) {
            await crypto.verifySigned(
              signPublicKey,
              await crypto.sign(randomPayload),
            );
          }
        },
      );
    },
  );
}
