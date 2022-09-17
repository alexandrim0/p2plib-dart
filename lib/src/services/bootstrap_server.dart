import 'dart:io';
import 'dart:typed_data';
import 'package:p2plib/p2plib.dart';

void log(String str) {
  print("${DateTime.now()} $str");
}

String shortHex(PubKey key) {
  return key.hex.substring(0, 10);
}

class Addresses {
  final Peer? ipv4;
  final Peer? ipv6;
  const Addresses({required this.ipv4, required this.ipv6});
  @override
  String toString() {
    return '[$ipv4, $ipv6]';
  }
}

class BootstrapServer {
  final int port;
  final Map<PubKey, Addresses> _peers = {};
  final UdpConnection connection;
  final KeyPairData keyPair;
  final PubKey myPubKey;

  BootstrapServer({required this.keyPair, required this.port})
      : connection = UdpConnection(ipv4Port: port),
        myPubKey = PubKey.keys(
            encryptionKey: keyPair.pubKey, signKey: keyPair.pubKey) {
    connection.udpData.stream.listen((event) {
      onMessage(event.data, event.peer);
    }, onError: (Object error) async {
      stop();
      await run();
    });
  }

  void stop() async {
    await connection.stop();
  }

  Future<void> run() async {
    await connection.start();
    log("Server started: ${connection.localAddresses}");
  }

  void onMessage(Uint8List data, Peer peer) {
    try {
      final packet = BootstrapServerPacket.deserialize(data);
      if (packet.header.topic == CanaryPacket.topic) {
        log("Incoming service ping packet from $peer");
        connection.send(peer, CanaryPacket().pack());
        return;
      }
      log("Message from $peer srckey: ${packet.header.srcKey}, dstKey ${packet.header.dstKey}, topic: ${packet.header.topic}, ack ${packet.header.ack}");
      if (packet.header.topic != BootsrapServerHandler.myTopic) {
        _proxy(packet.header.dstKey, data, peer);
        return;
      }
      _incomingPacket(packet, peer);
    } catch (err) {
      log("Error: incorrect packet from $peer: $err");
      return;
    }
  }

  void _proxy(PubKey dstKey, Uint8List data, Peer from) async {
    final to = _peers[dstKey];
    if (to == null) {
      log("Error: [proxy] request to ${shortHex(dstKey)} from $from, peer NOT FOUND");
      return;
    }
    log("[proxy] Request to ${shortHex(dstKey)} from $from, peer found at $to");

    if (to.ipv4 != null) {
      final bytes = connection.send(to.ipv4!, data);
      log("[proxy] send to ${to.ipv4!} $bytes bytes");
    }
    if (to.ipv6 != null) {
      final bytes = connection.send(to.ipv6!, data);
      log("[proxy] send to ${to.ipv6!} $bytes bytes");
    }
  }

  void _incomingPacket(BootstrapServerPacket packet, Peer peer) async {
    log("Incoming packet from $peer");
    BootstrapServerPacketBody? body;

    final unsignedData = await P2PCrypto()
        .openSign(packet.header.srcKey.signKey(), packet.bodyData);
    body = BootstrapServerPacketBody.deserialize(unsignedData);

    switch (body.type) {
      case BootsrapServerMsgType.registrationRequest:
        log("Registration request from $peer, pubkey: ${shortHex(packet.header.srcKey)}");
        _onRegistrationRequest(packet.header, peer);
        break;
      case BootsrapServerMsgType.searchRequest:
        log("Search request from $peer(${shortHex(packet.header.srcKey)})");
        _onSearchRequest(packet.header, body, peer);
        break;
      default:
        break;
    }
  }

  void _onRegistrationRequest(Header header, Peer peer) async {
    final registerPubKey = header.srcKey;
    _peers[registerPubKey] ??= Addresses(ipv4: null, ipv6: null);
    if (peer.address.type == InternetAddressType.IPv4) {
      _peers[registerPubKey] =
          Addresses(ipv4: peer, ipv6: _peers[registerPubKey]!.ipv6);
    } else if (peer.address.type == InternetAddressType.IPv6) {
      _peers[registerPubKey] =
          Addresses(ipv4: _peers[registerPubKey]!.ipv4, ipv6: peer);
    }

    final body = BootstrapServerPacketBody(
        BootsrapServerMsgType.registrationResponse, Uint8List(0));
    final signedData =
        await P2PCrypto().sign(keyPair.secretKey, body.serialize());
    final packet = BootstrapServerPacket(
        Header.genId(2, myPubKey, registerPubKey, Encrypted.signed, Ack.no),
        signedData);

    connection.send(peer, packet.serialize());
  }

  void _onSearchRequest(
      Header header, BootstrapServerPacketBody body, Peer peer) {
    final searchRequest = SearchRequest.deserialize(body.data);
    final requestPubKey = searchRequest.peer;
    log("Peer: $peer searching for ${shortHex(requestPubKey)}");

    _sendSearchResponce(header.srcKey, requestPubKey, peer);
  }

  void _sendSearchResponce(
      PubKey dstKey, PubKey requestedKey, Peer dstPeer) async {
    final requestedAdresses =
        _peers[requestedKey] ?? Addresses(ipv4: null, ipv6: null);
    SearchStatus status = SearchStatus.failed;
    if (requestedAdresses.ipv4 != null || requestedAdresses.ipv6 != null) {
      status = SearchStatus.succes;
    }

    log("Send search status of $requestedAdresses($requestedKey), status:{$status} to $dstPeer($dstKey)");
    final bodyData = SearchResponse(
        status: status,
        pubKey: requestedKey,
        peerIpv4: requestedAdresses.ipv4,
        peerIpv6: requestedAdresses.ipv6);
    final body = BootstrapServerPacketBody(
        BootsrapServerMsgType.searchResponse, bodyData.serialize());
    final signedData =
        await P2PCrypto().sign(keyPair.secretKey, body.serialize());
    final packet = BootstrapServerPacket(
        Header.genId(2, myPubKey, dstKey, Encrypted.signed, Ack.no),
        signedData);
    int bytes = connection.send(dstPeer, packet.serialize());
    log("Sent bytes $bytes to $dstPeer($dstKey)");
  }
}

class BootstrapServerPacket {
  final Header header;
  final Uint8List bodyData;
  const BootstrapServerPacket(this.header, this.bodyData);

  factory BootstrapServerPacket.deserialize(Uint8List data) {
    final header = Header.deserialize(data);
    final bodyData = data.sublist(Header.length);
    return BootstrapServerPacket(header, bodyData);
  }

  Uint8List serialize() {
    final builder = BytesBuilder();
    builder.add(header.serialize());
    builder.add(bodyData);
    return builder.toBytes();
  }
}
