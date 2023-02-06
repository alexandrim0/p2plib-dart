import 'package:test/test.dart';

import 'mock.dart';

main() async {
  final crypto = P2PCrypto();
  await crypto.init(P2PCryptoKeys.empty()..seed = proxySeed);
  final encPublicKey = crypto.cryptoKeys.encPublicKey;
  final signPublicKey = crypto.cryptoKeys.signPublicKey;
  final emptyMessage = P2PMessage(
    header: P2PPacketHeader(
      issuedAt: DateTime.now().millisecondsSinceEpoch,
      id: genRandomInt(),
    ),
    srcPeerId: proxyPeerId,
    dstPeerId: proxyPeerId,
  );
  final notEmptyMessage = emptyMessage.copyWith(payload: randomPayload);
  const stressCount = 100000;

  group(
    'Base',
    () {
      test(
        'P2PCrypto seed',
        () => expect(
          P2PPeerId.fromKeys(
            encryptionKey: encPublicKey,
            signKey: signPublicKey,
          ).toString(),
          proxyPeerId.toString(),
        ),
      );
      test(
        'P2PCrypto seal/unseal',
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
        'P2PCrypto sign/unsign',
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
        'P2PCrypto stress test: seal/unseal',
        () async {
          for (var i = 0; i < stressCount; i++) {
            await crypto.unseal(await crypto.seal(notEmptyMessage));
          }
        },
        timeout: Timeout(Duration(minutes: 1)),
      );

      test(
        'P2PCrypto stress test: sign/unsign',
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
