import 'dart:async';
import 'dart:typed_data';

import 'package:p2plib/p2plib.dart';

class BootsrapServerHandler extends TopicHandler {
  static const myTopic = 2;
  bool isRegistred = false;
  final Peer? serverAddressIpv4;
  final Peer? serverAddressIpv6;
  final Map<PubKey, Completer> _registryCompleters = {};
  final Map<PubKey, Completer<List<Peer>>> _searchCompleters = {};

  BootsrapServerHandler(
      {required Router router,
      required this.serverAddressIpv4,
      required this.serverAddressIpv6})
      : super(router);

  @override
  void onMessage(Header header, Uint8List data, Peer peer) {
    try {
      final packet = BootstrapServerPacketBody.deserialize(data);
      _incomingPacket(header, packet, peer);
    } catch (_) {}
  }

  @override
  Uint64List topics() {
    return Uint64List.fromList([myTopic]);
  }

  Future registerMe({Duration? timeout}) async {
    timeout ??= Settings.defaultTimeout;
    final me = router.pubKey;
    if (_registryCompleters.containsKey(me)) {
      return _registryCompleters[me]!.future.timeout(timeout, onTimeout: () {
        _registryCompleters.remove(me);
        throw TimeoutException('[BootstrapServer] Request timeout');
      });
    }

    final completer = Completer();
    _registryCompleters[router.pubKey] = completer;
    final data = BootstrapServerPacketBody(
            BootsrapServerMsgType.registrationRequest, Uint8List(0))
        .serialize();

    if (serverAddressIpv4 != null) {
      await router.sendSigned(myTopic, serverAddressIpv4!, data);
    }
    if (serverAddressIpv6 != null) {
      await router.sendSigned(myTopic, serverAddressIpv6!, data);
    }

    return completer.future.timeout(timeout, onTimeout: () {
      _registryCompleters.remove(me);
      throw TimeoutException('[BootstrapServer] Request timeout');
    });
  }

  Future<List<Peer>> findPeer(PubKey requestedPubKey,
      {Duration? timeout}) async {
    timeout ??= Settings.defaultTimeout;
    final completer = Completer<List<Peer>>();
    if (!isRegistred) {
      try {
        await registerMe();
      } catch (_) {
        completer.completeError(BoostrapServerConnectionError);
        return completer.future;
      }
    }
    _searchCompleters[requestedPubKey] = completer;
    final searchPacket = BootstrapServerPacketBody(
            BootsrapServerMsgType.searchRequest,
            SearchRequest(requestedPubKey).serialize())
        .serialize();
    if (serverAddressIpv4 != null) {
      await router.sendSigned(myTopic, serverAddressIpv4!, searchPacket);
    }
    if (serverAddressIpv6 != null) {
      await router.sendSigned(myTopic, serverAddressIpv6!, searchPacket);
    }
    return completer.future.timeout(timeout, onTimeout: () {
      _searchCompleters.remove(requestedPubKey);
      return <Peer>[];
    });
  }

  void _incomingPacket(
      Header header, BootstrapServerPacketBody body, Peer peer) {
    switch (body.type) {
      case BootsrapServerMsgType.registrationResponse:
        _onRegistreResponse(header, body);
        break;
      case BootsrapServerMsgType.searchResponse:
        _onSearchResponse(header, body);
        break;
      default:
        break;
    }
  }

  void _onRegistreResponse(Header header, BootstrapServerPacketBody body) {
    final me = router.pubKey;
    final completer = _registryCompleters[me];
    if (completer == null) {
      return;
    }
    isRegistred = true;
    _registryCompleters.remove(me);
    completer.complete();
  }

  void _onSearchResponse(Header header, BootstrapServerPacketBody body) {
    final response = SearchResponse.deserialize(body.data);
    final completer = _searchCompleters[response.pubKey];
    if (completer == null) {
      return;
    }
    _searchCompleters.remove(header.srcKey);
    List<Peer> peers = [];
    if (response.peerIpv4 != null) {
      peers.add(response.peerIpv4!);
    }
    if (response.peerIpv6 != null) {
      peers.add(response.peerIpv6!);
    }
    for (var peer in peers) {
      router.addPeer(response.pubKey, peer, enableSearch: false);
    }
    completer.complete(peers);
  }
}

class BoostrapServerConnectionError implements Exception {
  @override
  String toString() =>
      '[Bootstrap Server Handler] Cannot connect to bootstrap server';
}
