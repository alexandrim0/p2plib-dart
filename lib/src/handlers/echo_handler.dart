import 'dart:async';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:p2plib/src/settings.dart';

import '../pubkey.dart';
import '../router.dart';
import '../peer.dart';
import '../utils/utils.dart';
import '../packet/header.dart';
import '../packet/echo_packet.dart';
import 'handler.dart';

class EchoResult {
  final PubKey pubKey;
  final bool status;
  const EchoResult(this.pubKey, this.status);

  @override
  bool operator ==(Object other) =>
      other is EchoResult && pubKey == other.pubKey && status == other.status;

  @override
  int get hashCode {
    return Object.hashAll([pubKey, status]);
  }
}

class EchoHandler extends TopicHandler {
  static const _topic = 77;
  final Map<PubKey, EchoCompleter> _completers = {};
  final echo = StreamController<EchoResult>.broadcast();

  EchoHandler(Router router) : super(router);

  @override
  void onMessage(Header header, Uint8List data, Peer peer) {
    try {
      final packet = EchoPacket.deserialize(data);
      _incomingPacket(header, packet, peer);
    } catch (_) {}
  }

  @override
  Uint64List topics() {
    return Uint64List.fromList([_topic]);
  }

  Future<void> sendEcho(PubKey dstKey, {Duration? timeout}) async {
    timeout ??= Settings.defaultTimeout;
    final completer = Completer();
    final requestId = randomBytes(length: 64);
    _completers[dstKey] = EchoCompleter(completer, requestId);

    final echoPacket = _createRequestPacket(dstKey, requestId);
    try {
      await router
          .sendTo(_topic, dstKey, echoPacket)
          .onError((error, stackTrace) {
        _completers.remove(dstKey);
      });
    } catch (_) {
      _completers.remove(dstKey);
    }

    return completer.future.timeout(timeout, onTimeout: () {
      _onRequestTimeout(dstKey);
    });
  }

  void _incomingPacket(Header header, EchoPacket packet, Peer peer) {
    if (header.dstKey != router.pubKey) {
      return;
    }
    if (packet.type == EchoPacketType.request) {
      router.sendTo(_topic, header.srcKey,
          EchoPacket(EchoPacketType.response, packet.id).serialize(),
          encrypted: Encrypted.encrypted);
      return;
    }

    final echoCompleter = _completers[header.srcKey]!;
    if (_checkAnswer(header, packet, echoCompleter)) {
      echoCompleter.completer.complete();
      echo.add(EchoResult(header.srcKey, true));
    }
  }

  void _onRequestTimeout(PubKey pubKey) {
    echo.add(EchoResult(pubKey, false));
    _completers.remove(pubKey);
    throw TimeoutException('[EchoHandler] Request timeout');
  }

  Uint8List _createRequestPacket(PubKey dstKey, Uint8List id) {
    final packet = EchoPacket(EchoPacketType.request, id);
    return packet.serialize();
  }

  bool _checkAnswer(
      Header header, EchoPacket incomingPacket, EchoCompleter completer) {
    return IterableEquality().equals(completer.requestedId, incomingPacket.id);
  }
}

class EchoCompleter {
  final Completer completer;
  final Uint8List requestedId;
  EchoCompleter(this.completer, this.requestedId);
}
