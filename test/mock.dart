import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';

export 'package:p2plib/p2plib.dart';

const initTime = Duration(milliseconds: 250);
final localAddress = InternetAddress.loopbackIPv4;
final randomPeerId = P2PPeerId(value: getRandomBytes(P2PPeerId.length));
final randomPayload = getRandomBytes(64);
final token = P2PToken(value: randomPayload);
final proxySeed = base64Decode('tuTfQVH3qgHZ751JtEja_ZbkY-EF0cbRzVDDO_HNrmY=');
final proxyPeerId = P2PPeerId(
  value: base64Decode(
      'xD_eApw8bN2EDDirUzCoEsOpSbGXfFD0WYr7q7hWjVUARgW4EQ7CTjMT_SqAfItrfS4BGl6sU-rnSWCwuOtv3Q=='),
);
final proxyAddress = P2PFullAddress(
  address: localAddress,
  isStatic: true,
  isLocal: true,
  port: 2022,
);
final aliceAddress = P2PFullAddress(
  address: localAddress,
  isLocal: true,
  port: 3022,
);
final bobAddress = P2PFullAddress(
  address: localAddress,
  isLocal: true,
  port: 4022,
);

P2PRoute getProxyRoute() => P2PRoute(
      peerId: proxyPeerId,
      canForward: true,
      address: MapEntry(proxyAddress, DateTime.now().millisecondsSinceEpoch),
    );

void log(debugLabel, message) => print('[$debugLabel] $message');

Future<P2PRouterL2> createRouter({
  required final P2PFullAddress address,
  final Uint8List? seed,
  final String? debugLabel,
}) async {
  final router = P2PRouterL2(
    transports: [P2PUdpTransport(bindAddress: address)],
    logger: (message) => print('[$debugLabel] $message'),
  )
    ..requestTimeout = const Duration(seconds: 2)
    ..peerOnlineTimeout = const Duration(seconds: 2);
  final cryptoKeys = P2PCryptoKeys.empty();
  if (seed != null) cryptoKeys.seed = seed;
  await router.init(cryptoKeys);
  return router;
}

Future<Isolate> createProxy({
  final P2PFullAddress? address,
  final String? debugLabel = 'Proxy',
}) async {
  final isolate = await Isolate.spawn(
    (_) async {
      final router = P2PRouterL0(
        transports: [P2PUdpTransport(bindAddress: address ?? proxyAddress)],
        logger: (message) => print('[$debugLabel] $message'),
      )
        ..requestTimeout = const Duration(seconds: 2)
        ..peerOnlineTimeout = const Duration(seconds: 2);
      await router.init(P2PCryptoKeys.empty()..seed = proxySeed);
      await router.start();
    },
    null,
    debugName: debugLabel,
  );
  await Future.delayed(initTime);
  return isolate;
}
