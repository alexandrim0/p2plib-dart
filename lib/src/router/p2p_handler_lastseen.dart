part of 'router.dart';

mixin P2PHandlerLastSeen on P2PRouterBase {
  final _lastSeenController =
      StreamController<MapEntry<P2PPeerId, bool>>.broadcast();

  Stream<MapEntry<P2PPeerId, bool>> get lastSeenStream =>
      _lastSeenController.stream;

  bool getPeerStatus(final P2PPeerId peerId) {
    final lastSeen = _resolveCache[peerId]?.values.reduce(max);
    return lastSeen == null
        ? false
        : lastSeen + requestTimeout.inMilliseconds >
            DateTime.now().millisecondsSinceEpoch;
  }

  Future<bool> pingPeer(final P2PPeerId peerId) async {
    try {
      await sendMessage(isConfirmable: true, dstPeerId: peerId);
      _lastSeenController.add(MapEntry<P2PPeerId, bool>(peerId, true));
      return true;
    } catch (_) {}
    _lastSeenController.add(MapEntry<P2PPeerId, bool>(
      peerId,
      getPeerStatus(peerId),
    ));
    return false;
  }

  void _processLastSeen(final P2PMessage message) {
    _resolveCache[message.srcPeerId]?[message.header.srcFullAddress!] =
        DateTime.now().millisecondsSinceEpoch;
    _lastSeenController.add(MapEntry<P2PPeerId, bool>(message.srcPeerId, true));
  }
}
