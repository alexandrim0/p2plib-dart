import 'dart:io';
import 'dart:isolate';
import 'package:p2plib/p2plib.dart';

export 'package:p2plib/p2plib.dart';

const initTime = Duration(milliseconds: 250);
final localAddress = InternetAddress.anyIPv4;
final proxyAddress = P2PFullAddress(address: localAddress, port: 2022);
final proxyAddresses = [proxyAddress];
final aliceAddress = P2PFullAddress(address: localAddress, port: 3022);
final bobAddress = P2PFullAddress(address: localAddress, port: 4022);
final randomPeerId = P2PPeerId(value: getRandomBytes(P2PPeerId.length));
final payload = getRandomBytes(64);
final token = P2PToken(value: payload);

Future<P2PRouter> createRouter({
  required final P2PFullAddress address,
  final Uint8List? seedEnc,
  final Uint8List? seedSign,
  final String? debugLabel,
}) async {
  final router = P2PRouter(
    transports: [P2PUdpTransport(fullAddress: address)],
    debugLabel: debugLabel,
    logger: print,
  );
  final cryptoKeys = P2PCryptoKeys.empty();
  if (seedEnc != null) cryptoKeys.encSeed = seedEnc;
  if (seedSign != null) cryptoKeys.signSeed = seedSign;
  await router.init(cryptoKeys);
  return router;
}

Future<Isolate> createProxy({
  final P2PFullAddress? address,
  final String? debugLabel = 'Proxy',
}) async {
  final isolate = await Isolate.spawn(
    (_) async {
      final router = P2PRouterBase(
        transports: [P2PUdpTransport(fullAddress: address ?? proxyAddress)],
        debugLabel: debugLabel,
        logger: print,
      );
      await router.init(P2PCryptoKeys.empty()
        ..encSeed = proxySeedEnc
        ..signSeed = proxySeedSign);
      await router.start();
    },
    null,
    debugName: debugLabel,
  );
  await Future.delayed(initTime);
  return isolate;
}

final proxySeedEnc = Uint8List.fromList([
  182,
  228,
  223,
  65,
  81,
  247,
  170,
  1,
  217,
  239,
  157,
  73,
  180,
  72,
  218,
  253,
  150,
  228,
  99,
  225,
  5,
  209,
  198,
  209,
  205,
  80,
  195,
  59,
  241,
  205,
  174,
  102,
]);
final proxySeedSign = Uint8List.fromList([
  118,
  169,
  155,
  89,
  27,
  72,
  96,
  249,
  241,
  123,
  39,
  61,
  245,
  52,
  72,
  247,
  1,
  122,
  250,
  98,
  168,
  226,
  43,
  217,
  159,
  57,
  220,
  68,
  136,
  120,
  95,
  114,
]);
final proxyPeerId = P2PPeerId(
    value: Uint8List.fromList([
  196,
  63,
  222,
  2,
  156,
  60,
  108,
  221,
  132,
  12,
  56,
  171,
  83,
  48,
  168,
  18,
  195,
  169,
  73,
  177,
  151,
  124,
  80,
  244,
  89,
  138,
  251,
  171,
  184,
  86,
  141,
  85,
  78,
  196,
  214,
  52,
  86,
  14,
  243,
  90,
  58,
  169,
  227,
  177,
  184,
  235,
  17,
  197,
  230,
  92,
  240,
  205,
  8,
  9,
  78,
  32,
  254,
  140,
  251,
  79,
  120,
  134,
  127,
  224,
]));
const proxyPeerIdAsBase64 =
    'xD_eApw8bN2EDDirUzCoEsOpSbGXfFD0WYr7q7hWjVVOxNY0Vg7zWjqp47G46xHF5lzwzQgJTiD-jPtPeIZ_4A==';
