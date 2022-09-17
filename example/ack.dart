import 'dart:async';
import 'dart:core';
import 'package:p2plib/p2plib.dart';

main(List<String> arguments) async {
  final crypto = P2PCrypto();
  await crypto.init();

  final bobEncryptionKeyPair = await P2PCrypto().encryptionKeyPair();
  final bobSignKeyPair = await P2PCrypto().signKeyPair();

  final bobRouter = Router(UdpConnection(),
      encryptionKeyPair: bobEncryptionKeyPair, signKeyPair: bobSignKeyPair);

  await bobRouter.run();
  try {
    print("Sending packet with ack to myself. Should get an answer:");
    await bobRouter.sendTo(123, bobRouter.pubKey, randomBytes(),
        encrypted: Encrypted.no, ack: Ack.required);
    print("Success: future completed with no error!");
  } catch (err) {
    print("Failed: $err");
  }

  try {
    print(
        "Sending packet with ack to non existed peer. Should get an timeout error:");
    await bobRouter.sendTo(
        123, PubKey(randomBytes(length: PubKey.length)), randomBytes(),
        encrypted: Encrypted.no, ack: Ack.required);
    print("Failed. Future completed with no errors.");
  } on TimeoutException catch (err) {
    print("Success: future completed with timeout exception: ($err).");
  }
}
