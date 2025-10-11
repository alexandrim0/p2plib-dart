// ignore_for_file: avoid_print //

import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';

export 'package:p2plib/p2plib.dart';

const initTime = Duration(milliseconds: 250);
final InternetAddress localAddress = InternetAddress.loopbackIPv4;
final randomPeerId = PeerId(value: getRandomBytes(PeerId.length));
final Uint8List randomPayload = getRandomBytes(1024);
final token = Token(value: randomPayload);
final Uint8List proxySeed = base64Decode(
  'tuTfQVH3qgHZ751JtEja_ZbkY-EF0cbRzVDDO_HNrmY=',
);
final proxyPeerId = PeerId(
  value: base64Decode(
    // ignore: lines_longer_than_80_chars //
    'xD_eApw8bN2EDDirUzCoEsOpSbGXfFD0WYr7q7hWjVUARgW4EQ7CTjMT_SqAfItrfS4BGl6sU-rnSWCwuOtv3Q==',
  ),
);
final ({FullAddress ip, AddressProperties properties})
proxyAddressWithProperties = (
  ip: FullAddress(address: localAddress, port: 2022),
  properties: AddressProperties(isStatic: true, isLocal: true),
);
final ({FullAddress ip, AddressProperties properties})
aliceAddressWithProperties = (
  ip: FullAddress(address: localAddress, port: 3022),
  properties: AddressProperties(isLocal: true),
);
final ({FullAddress ip, AddressProperties properties})
bobAddressWithProperties = (
  ip: FullAddress(address: localAddress, port: 4022),
  properties: AddressProperties(isLocal: true),
);

Route getProxyRoute() => Route(
  peerId: proxyPeerId,
  canForward: true,
  address: proxyAddressWithProperties,
);

void log(String debugLabel, String message) => print('[$debugLabel] $message');

Future<RouterL2> createRouter({
  required FullAddress address,
  Uint8List? seed,
  String? debugLabel,
}) async {
  final router =
      RouterL2(
          transports: [TransportUdp(bindAddress: address)],
          logger: (message) => print('[$debugLabel] $message'),
        )
        ..messageTTL = const Duration(seconds: 2)
        ..peerOnlineTimeout = const Duration(seconds: 2);
  await router.init(seed);
  return router;
}

Future<Isolate> createProxy({
  FullAddress? address,
  String? debugLabel = 'Proxy',
}) async {
  final isolate = await Isolate.spawn(
    (_) async {
      final router = RouterL0(
        transports: [
          TransportUdp(bindAddress: address ?? proxyAddressWithProperties.ip),
        ],
        logger: (message) => print('[$debugLabel] $message'),
      )..messageTTL = const Duration(seconds: 2);
      await router.init(proxySeed);
      await router.start();
    },
    null,
    debugName: debugLabel,
  );
  await Future.delayed(initTime, () {});
  return isolate;
}
