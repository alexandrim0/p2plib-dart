import 'dart:io';

import 'package:test/test.dart';

import 'mock.dart';

void main() async {
  test(
    'PeerId equality',
    () {
      final bytesA = getRandomBytes(64);
      final bytesB = bytesA.buffer.asUint8List();
      final peerIdA = P2PPeerId(value: bytesA);
      final peerIdB = P2PPeerId(value: bytesB);

      expect(proxyPeerId == randomPeerId, false);
      expect(peerIdA == peerIdB, true);
    },
  );

  test(
    'P2PMessageHeader equality and serialization',
    () {
      final headerA = P2PPacketHeader(id: genRandomInt());
      final headerB = headerA.copyWith(
        messageType: P2PPacketType.confirmation,
      );
      final headerC = P2PPacketHeader.fromBytes(headerA.toBytes());

      expect(headerA == headerB, false);
      expect(headerA == headerC, true);
    },
  );

  test(
    'P2PMessage equality and serialization',
    () {
      final messageId = genRandomInt();
      final message = P2PMessage(
        header: P2PPacketHeader(id: messageId),
        srcPeerId: randomPeerId,
        dstPeerId: randomPeerId,
      );
      final datagram = message.toBytes();

      expect(messageId == datagram.buffer.asInt64List(8, 1).first, true);
      final dstPeerId = P2PPeerId(
          value: datagram.sublist(
        P2PPacketHeader.length + P2PPeerId.length,
        P2PMessage.headerLength,
      ));
      expect(randomPeerId == dstPeerId, true);
    },
  );

  test(
    'FullAddress equality',
    () {
      final addressA = InternetAddress('127.0.0.1');
      final addressB = InternetAddress('127.0.0.1');
      final addressC = InternetAddress('127.0.0.2');

      expect(addressA == addressB, true);
      expect(addressA == addressC, false);

      final fullAddressA = P2PFullAddress(
        address: addressA,
        isLocal: true,
        port: 5000,
      );
      final fullAddressB = P2PFullAddress(
        address: addressB,
        isLocal: true,
        port: 5000,
      );
      final fullAddressC = P2PFullAddress(
        address: addressC,
        isLocal: true,
        port: 5000,
      );
      final fullAddressD = P2PFullAddress(
        address: addressA,
        isLocal: true,
        port: 5001,
      );
      final fullAddressE = P2PFullAddress(
        address: addressC,
        isLocal: true,
        port: 5001,
      );

      expect(fullAddressA.hashCode == fullAddressB.hashCode, true);
      expect(fullAddressA.hashCode == fullAddressC.hashCode, false);
      expect(fullAddressA.hashCode == fullAddressD.hashCode, false);
      expect(fullAddressC.hashCode == fullAddressD.hashCode, false);
      expect(fullAddressD.hashCode == fullAddressE.hashCode, false);
      expect(fullAddressA == fullAddressB, true);
      expect(fullAddressA == fullAddressC, false);
      expect(fullAddressA == fullAddressD, false);
      expect(fullAddressC == fullAddressD, false);
      expect(fullAddressD == fullAddressE, false);
    },
  );
}
