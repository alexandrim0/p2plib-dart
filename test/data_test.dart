import 'dart:io';

import 'package:test/test.dart';

import 'mock.dart';

void main() async {
  test(
    'PeerId equality',
    () {
      final bytesA = getRandomBytes(64);
      final bytesB = bytesA.buffer.asUint8List();
      final peerIdA = PeerId(value: bytesA);
      final peerIdB = PeerId(value: bytesB);

      expect(proxyPeerId == randomPeerId, false);
      expect(peerIdA == peerIdB, true);
    },
  );

  test(
    'MessageHeader equality and serialization',
    () {
      final headerA = PacketHeader(
        issuedAt: DateTime.now().millisecondsSinceEpoch,
        id: genRandomInt(),
      );
      final headerB = headerA.copyWith(
        messageType: PacketType.confirmation,
      );
      final headerC = headerA.copyWith(
        id: genRandomInt(),
      );
      final headerD = PacketHeader.fromBytes(headerA.toBytes());

      expect(headerA == headerB, true);
      expect(headerA == headerC, false);
      expect(headerA == headerD, true);
    },
  );

  test(
    'Message serialization',
    () {
      final messageId = genRandomInt();
      final message = Message(
        header: PacketHeader(
          issuedAt: DateTime.now().millisecondsSinceEpoch,
          id: messageId,
        ),
        srcPeerId: randomPeerId,
        dstPeerId: randomPeerId,
      );
      final datagram = message.toBytes();

      expect(PacketHeader.fromBytes(datagram).id, messageId);
      expect(Message.getDstPeerId(datagram), randomPeerId);
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

      final fullAddressA = FullAddress(
        address: addressA,
        isLocal: true,
        port: 5000,
      );
      final fullAddressB = FullAddress(
        address: addressB,
        isLocal: true,
        port: 5000,
      );
      final fullAddressC = FullAddress(
        address: addressC,
        isLocal: true,
        port: 5000,
      );
      final fullAddressD = FullAddress(
        address: addressA,
        isLocal: true,
        port: 5001,
      );
      final fullAddressE = FullAddress(
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
    'Route.addHeader',
    () {
      Route.maxStoredHeaders = 5;
      final now = DateTime.now().millisecondsSinceEpoch;
      final firstHeader = PacketHeader(issuedAt: now, id: genRandomInt());
      final route = Route(
        peerId: proxyPeerId,
        header: firstHeader,
      );

      for (var i = 0; i < 4; i++) {
        route.addHeader(PacketHeader(issuedAt: now, id: genRandomInt()));
      }
      expect(route.lastHeaders.contains(firstHeader), true);

      route.addHeader(PacketHeader(issuedAt: now, id: genRandomInt()));
      expect(route.lastHeaders.contains(firstHeader), false);
    },
  );

  test(
    'Route.getActualAddresses, removeStaleAddresses',
    () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final staleAt = now - 3000;
      final actualAddress = FullAddress(
        address: localAddress,
        isLocal: true,
        isStatic: false,
        port: 1234,
      );
      final staleAddress = FullAddress(
        address: localAddress,
        isLocal: true,
        isStatic: false,
        port: 4321,
      );
      final staticAddress = FullAddress(
        address: localAddress,
        isLocal: true,
        isStatic: true,
        port: 2345,
      );
      final route = Route(
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
      final addr1 = FullAddress(
        address: proxyAddress.address,
        port: proxyAddress.port,
        isLocal: true,
        isStatic: false,
      );
      final addr2 = FullAddress(
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
