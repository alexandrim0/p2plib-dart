part of 'router.dart';

class RouterL3 extends RouterL2 {
  RouterL3({
    super.crypto,
    super.transports,
    super.keepalivePeriod,
    super.messageTTL,
    super.logger,
  });

  final Map<String, List<InternetAddress>> _addresses = {};

  @override
  Future<void> start({int port = TransportUdp.defaultPort}) async {
    final ifs = <InternetAddress>{};
    for (final nIf in await NetworkInterface.list()) {
      ifs.addAll(nIf.addresses);
    }
    for (final address in ifs) {
      transports.add(
        TransportUdp(
          bindAddress: FullAddress(address: address, port: port),
        ),
      );
    }
    await super.start();
  }

  @override
  void stop() {
    super.stop();
    transports.clear();
  }

  /// bsName is a dns name
  /// bsPeerId is base64 encoded string of PeerId
  Future<void> addBootstrap({
    required String bsName,
    required String bsPeerId,
    int port = TransportUdp.defaultPort,
  }) async {
    stop();
    _addresses[bsPeerId] =
        await InternetAddress.lookup(bsName).timeout(messageTTL);
    final addressProperties = AddressProperties(isStatic: true);
    for (final e in _addresses.entries) {
      final peerId = PeerId(value: base64Decode(e.key));
      for (final address in e.value) {
        addPeerAddress(
          canForward: true,
          peerId: peerId,
          address: FullAddress(address: address, port: port),
          properties: addressProperties,
        );
      }
    }
    await start();
  }

  void removeAllBootstraps() {
    for (final e in _addresses.entries) {
      removePeerAddress(PeerId(value: base64Decode(e.key)));
    }
    _addresses.clear();
  }
}
