import 'package:test/test.dart';

import 'mock.dart';

main() async {
  final crypto = P2PCrypto();
  await crypto.init(P2PCryptoKeys(
    encSeed: proxySeedEnc,
    signSeed: proxySeedSign,
  ));
  final encPublicKey = crypto.cryptoKeys.encPublicKey!;
  final signPublicKey = crypto.cryptoKeys.signPublicKey!;
  final message = P2PMessage(
    header: P2PPacketHeader(id: genRandomInt()),
    srcPeerId: proxyPeerId,
    dstPeerId: proxyPeerId,
  );
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
          ).asHex,
          proxyPeerIdAsHex,
        ),
      );
      test(
        'P2PCrypto seal/unseal',
        () async {
          // empty message
          expect(await crypto.unseal(await crypto.seal(message)), message);

          // message with payload
          final m = message.copyWith(payload: payload);
          expect(await crypto.unseal(await crypto.seal(m)), m);
        },
      );

      test(
        'P2PCrypto encrypt/decrypt',
        () async {
          final encryptedData = await crypto.encrypt(
            encPublicKey,
            payload,
          );
          final decryptedData = await crypto.decrypt(encryptedData);
          expect(P2PToken(value: payload), P2PToken(value: decryptedData));
        },
      );

      test(
        'P2PCrypto sign/unsign',
        () async {
          final signedData = await crypto.sign(payload);
          final unsignedData = await crypto.openSigned(
            signPublicKey,
            signedData,
          );
          expect(P2PToken(value: payload), P2PToken(value: unsignedData));
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
          final m = message.copyWith(payload: payload);
          for (var i = 0; i < stressCount; i++) {
            await crypto.unseal(await crypto.seal(m));
          }
        },
      );

      test(
        'P2PCrypto stress test: encrypt/decrypt',
        () async {
          for (var i = 0; i < stressCount; i++) {
            await crypto.decrypt(await crypto.encrypt(
              encPublicKey,
              payload,
            ));
          }
        },
      );

      test(
        'P2PCrypto stress test: sign/unsign',
        () async {
          for (var i = 0; i < stressCount; i++) {
            await crypto.openSigned(
              signPublicKey,
              await crypto.sign(payload),
            );
          }
        },
      );
    },
  );
}
