import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';

export 'package:p2plib/p2plib.dart';

const initTime = Duration(milliseconds: 250);
final localAddress = InternetAddress.loopbackIPv4;
final randomPeerId = PeerId(value: getRandomBytes(PeerId.length));
final randomPayload = getRandomBytes(64);
final token = Token(value: randomPayload);
final proxySeed = base64Decode('tuTfQVH3qgHZ751JtEja_ZbkY-EF0cbRzVDDO_HNrmY=');
final proxyPeerId = PeerId(
  value: base64Decode(
      'xD_eApw8bN2EDDirUzCoEsOpSbGXfFD0WYr7q7hWjVUARgW4EQ7CTjMT_SqAfItrfS4BGl6sU-rnSWCwuOtv3Q=='),
);
final proxyAddressWithProperties = MapEntry(
  FullAddress(address: localAddress, port: 2022),
  AddressProperties(isStatic: true, isLocal: true),
);
final aliceAddressWithProperties = MapEntry(
  FullAddress(address: localAddress, port: 3022),
  AddressProperties(isLocal: true),
);
final bobAddressWithProperties = MapEntry(
  FullAddress(address: localAddress, port: 4022),
  AddressProperties(isLocal: true),
);

Route getProxyRoute() => Route(
    peerId: proxyPeerId, canForward: true, address: proxyAddressWithProperties);

void log(debugLabel, message) => print('[$debugLabel] $message');

Future<RouterL2> createRouter({
  required final FullAddress address,
  final Uint8List? seed,
  final String? debugLabel,
}) async {
  final router = RouterL2(
    transports: [TransportUdp(bindAddress: address)],
    logger: (message) => print('[$debugLabel] $message'),
  )
    ..messageTTL = const Duration(seconds: 2)
    ..peerOnlineTimeout = const Duration(seconds: 2);
  final cryptoKeys = CryptoKeys.empty();
  if (seed != null) cryptoKeys.seed = seed;
  await router.init(cryptoKeys);
  return router;
}

Future<Isolate> createProxy({
  final FullAddress? address,
  final String? debugLabel = 'Proxy',
}) async {
  final isolate = await Isolate.spawn(
    (_) async {
      final router = RouterL0(
        transports: [
          TransportUdp(bindAddress: address ?? proxyAddressWithProperties.key)
        ],
        logger: (message) => print('[$debugLabel] $message'),
      )..messageTTL = const Duration(seconds: 2);
      await router.init(CryptoKeys.empty()..seed = proxySeed);
      await router.start();
    },
    null,
    debugName: debugLabel,
  );
  await Future.delayed(initTime);
  return isolate;
}
