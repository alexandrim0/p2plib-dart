part of 'router.dart';

mixin LastSeenHandler on P2PRouterBase {
  final _pingTasks = <PeerId>{};
  final _lastSeen = <PeerId, int>{};
  final _lastSeenController =
      StreamController<MapEntry<PeerId, bool>>.broadcast();

  var pingTimeout = P2PRouterBase.defaultTimeout;
  var pingPeriod = P2PRouterBase.defaultPeriod;
  Timer? _pingTimer;

  bool getPeerStatus(final PeerId peerId) {
    final lastSeen = _lastSeen[peerId];
    return lastSeen == null
        ? false
        : lastSeen + pingTimeout.inMilliseconds >
            DateTime.now().millisecondsSinceEpoch;
  }

  Future<bool> pingPeer(final PeerId peerId) async {
    try {
      await _sendEmptyConfirmableTo(peerId);
      return true;
    } catch (_) {}
    return false;
  }

  StreamSubscription<bool> trackPeer({
    required final PeerId peerId,
    required final void Function(bool status) onChange,
  }) {
    _pingTasks.add(peerId);
    _pingTimer ??= Timer.periodic(pingPeriod, _pingAll);
    return _lastSeenController.stream
        .where((event) => peerId == event.key)
        .map((event) => event.value)
        .listen(
          onChange,
          onDone: () => _pingTasks.remove(peerId),
        );
  }

  Future<void> _sendEmptyConfirmableTo(final PeerId dstPeerId);

  void _stopLastSeenHandler() {
    _lastSeen.clear();
    _pingTasks.clear();
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _processLastSeen(final P2PMessage message) {
    _lastSeen[message.srcPeerId] = DateTime.now().millisecondsSinceEpoch;
    if (_pingTasks.contains(message.srcPeerId)) {
      _lastSeenController.add(MapEntry<PeerId, bool>(message.srcPeerId, true));
    }
  }

  void _pingAll(_) {
    final stale =
        DateTime.now().millisecondsSinceEpoch - pingTimeout.inMilliseconds;
    for (final peerId in _pingTasks) {
      pingPeer(peerId);
      final lastSeen = _lastSeen[peerId];
      if (lastSeen == null || lastSeen < stale) {
        _lastSeenController.add(MapEntry<PeerId, bool>(peerId, false));
      }
    }
  }
}
