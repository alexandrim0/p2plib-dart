import 'dart:io';
import 'dart:typed_data';
import 'package:messagepack/messagepack.dart';
import 'package:p2plib/p2plib.dart';

enum BootsrapServerMsgType {
  registrationRequest,
  registrationResponse,
  searchRequest,
  searchResponse
}

class SearchRequest {
  final PubKey peer;
  const SearchRequest(this.peer);

  factory SearchRequest.deserialize(Uint8List data) {
    return SearchRequest(PubKey.keys(
        encryptionKey: data.sublist(0, 32), signKey: data.sublist(32, 64)));
  }

  Uint8List serialize() {
    return Uint8List.fromList(peer.data);
  }
}

enum SearchStatus { succes, failed }

class SearchResponse {
  final SearchStatus status;
  final PubKey pubKey;
  final Peer? peerIpv4;
  final Peer? peerIpv6;
  const SearchResponse(
      {required this.status,
      required this.pubKey,
      required this.peerIpv4,
      required this.peerIpv6});

  factory SearchResponse.deserialize(Uint8List data) {
    final u = Unpacker(data);
    final status = SearchStatus.values[u.unpackInt()!];
    final pubKey = PubKey(Uint8List.fromList(u.unpackBinary()));
    int n = u.unpackInt()!;
    Peer? peerIpv4;
    Peer? peerIpv6;
    if (n > 0) {
      n--;
      final address =
          InternetAddress.fromRawAddress(Uint8List.fromList(u.unpackBinary()));
      final port = u.unpackInt()!;
      if (address.type == InternetAddressType.IPv4) {
        peerIpv4 = Peer(address, port);
      } else if (address.type == InternetAddressType.IPv6) {
        peerIpv6 = Peer(address, port);
      }
    }
    if (n > 0) {
      n--;
      final address =
          InternetAddress.fromRawAddress(Uint8List.fromList(u.unpackBinary()));
      final port = u.unpackInt()!;
      if (address.type == InternetAddressType.IPv4) {
        peerIpv4 = Peer(address, port);
      } else if (address.type == InternetAddressType.IPv6) {
        peerIpv6 = Peer(address, port);
      }
    }

    return SearchResponse(
        status: status, pubKey: pubKey, peerIpv4: peerIpv4, peerIpv6: peerIpv6);
  }

  Uint8List serialize() {
    final p = Packer()
      ..packInt(status.index)
      ..packBinary(pubKey.data);
    int n = 0;
    if (peerIpv4 != null) n++;
    if (peerIpv6 != null) n++;
    p.packInt(n);
    if (peerIpv4 != null) {
      p.packBinary(peerIpv4!.address.rawAddress);
      p.packInt(peerIpv4!.port);
    }
    if (peerIpv6 != null) {
      p.packBinary(peerIpv6!.address.rawAddress);
      p.packInt(peerIpv6!.port);
    }

    return p.takeBytes();
  }
}

class BootstrapServerPacketBody {
  final BootsrapServerMsgType type;
  final Uint8List data;
  const BootstrapServerPacketBody(this.type, this.data);

  factory BootstrapServerPacketBody.deserialize(Uint8List data) {
    final bytes = ByteData.view(data.buffer);
    final type = BootsrapServerMsgType.values[bytes.getUint8(0)];
    return BootstrapServerPacketBody(type, data.sublist(1));
  }

  Uint8List serialize() {
    ByteData bytes = ByteData(1 + data.length);
    bytes.setUint8(0, type.index);
    int offset = 1;
    for (var byte in data) {
      bytes.setUint8(offset++, byte);
    }
    return bytes.buffer.asUint8List();
  }
}
