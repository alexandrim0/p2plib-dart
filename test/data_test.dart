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
      final headerA = P2PPacketHeader(
        issuedAt: DateTime.now().millisecondsSinceEpoch,
        id: genRandomInt(),
      );
      final headerB = headerA.copyWith(
        messageType: P2PPacketType.confirmation,
      );
      final headerC = headerA.copyWith(
        id: genRandomInt(),
      );
      final headerD = P2PPacketHeader.fromBytes(headerA.toBytes());

      expect(headerA == headerB, true);
      expect(headerA == headerC, false);
      expect(headerA == headerD, true);
    },
  );

  test(
    'P2PMessage serialization',
    () {
      final messageId = genRandomInt();
      final message = P2PMessage(
        header: P2PPacketHeader(
          issuedAt: DateTime.now().millisecondsSinceEpoch,
          id: messageId,
        ),
        srcPeerId: randomPeerId,
        dstPeerId: randomPeerId,
      );
      final datagram = message.toBytes();

      expect(P2PPacketHeader.fromBytes(datagram).id, messageId);
      expect(P2PMessage.getDstPeerId(datagram), randomPeerId);
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

  test(
    'P2PRoute.addHeader',
    () {
      P2PRoute.maxStoredHeaders = 5;
      final now = DateTime.now().millisecondsSinceEpoch;
      final firstHeader = P2PPacketHeader(issuedAt: now, id: genRandomInt());
      final route = P2PRoute(
        peerId: proxyPeerId,
        header: firstHeader,
      );

      for (var i = 0; i < 4; i++) {
        route.addHeader(P2PPacketHeader(issuedAt: now, id: genRandomInt()));
      }
      expect(route.lastHeaders.contains(firstHeader), true);

      route.addHeader(P2PPacketHeader(issuedAt: now, id: genRandomInt()));
      expect(route.lastHeaders.contains(firstHeader), false);
    },
  );

  test(
    'P2PRoute.getActualAddresses, removeStaleAddresses',
    () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final staleAt = now - 3000;
      final actualAddress = P2PFullAddress(
        address: localAddress,
        isLocal: true,
        isStatic: false,
        port: 1234,
      );
      final staleAddress = P2PFullAddress(
        address: localAddress,
        isLocal: true,
        isStatic: false,
        port: 4321,
      );
      final staticAddress = P2PFullAddress(
        address: localAddress,
        isLocal: true,
        isStatic: true,
        port: 2345,
      );
      final route = P2PRoute(
        peerId: proxyPeerId,
        addresses: {
          aliceAddress: now,
          bobAddress: now,
          actualAddress: now,
          staleAddress: staleAt - 1,
          staticAddress: staleAt - 1,
        },
      );

      final actualAddresses = route.getActualAddresses(staleAt: staleAt);
      expect(actualAddresses.contains(actualAddress), true);
      expect(actualAddresses.contains(staticAddress), true);
      expect(actualAddresses.contains(staleAddress), false);

      route.removeStaleAddresses(staleAt: staleAt);
      expect(route.addresses.containsKey(staleAddress), false);
      expect(route.addresses.containsKey(staticAddress), true);
    },
  );

  test(
    'FullAddress',
    () {
      final addr1 = P2PFullAddress(
        address: proxyAddress.address,
        port: proxyAddress.port,
        isLocal: true,
        isStatic: false,
      );
      final addr2 = P2PFullAddress(
        address: proxyAddress.address,
        port: proxyAddress.port,
        isLocal: false,
        isStatic: true,
      );
      final set = {addr1, addr2};

      expect(addr1, addr2);
      expect(addr1, addr2);
      expect(addr1.isLocal == addr2.isLocal, false);
      expect(addr1.isStatic == addr2.isStatic, false);
      expect(set.length, 1);
    },
  );
}
