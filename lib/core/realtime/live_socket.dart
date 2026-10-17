import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_frame.dart';

typedef ChannelFactory = WebSocketChannel Function(Uri uri);

enum LinkPhase { connecting, connected, reconnecting, unauthorized, closed }

class LinkStatus {
  const LinkStatus(this.phase, {this.retryIn, this.attempt = 0});

  final LinkPhase phase;

  /// Delay before the next attempt while [LinkPhase.reconnecting].
  final Duration? retryIn;
  final int attempt;

  static const initial = LinkStatus(LinkPhase.connecting);
}

/// The `/ws/live` client: reconnects with backoff 1 s, 2 s, 5 s, then every
/// 10 s; close code 4401 (bad token) stops retrying and reports
/// [onUnauthorized] (docs/02-api-contract.md §4). Sends `{"type":"ping"}`
/// every [pingEvery] so a dead link is noticed.
class LiveSocket {
  LiveSocket({
    required this.uri,
    required this.onFrame,
    required this.onStatus,
    required this.onUnauthorized,
    ChannelFactory? connect,
    this.pingEvery = const Duration(seconds: 15),
  }) : _connect = connect ?? WebSocketChannel.connect;

  final Uri uri;
  final void Function(LiveFrame frame) onFrame;
  final void Function(LinkStatus status) onStatus;
  final void Function() onUnauthorized;
  final Duration pingEvery;
  final ChannelFactory _connect;

  static const unauthorizedCloseCode = 4401;
  static const backoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  /// Delay before reconnect attempt number [failures] (0-based).
  static Duration backoffFor(int failures) =>
      backoff[failures.clamp(0, backoff.length - 1)];

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _ping;
  int _failures = 0;
  bool _closed = false;

  void start() {
    if (_closed) return;
    _open();
  }

  Future<void> _open() async {
    if (_closed) return;
    onStatus(
      _failures == 0
          ? const LinkStatus(LinkPhase.connecting)
          : LinkStatus(LinkPhase.connecting, attempt: _failures),
    );
    final WebSocketChannel channel;
    try {
      channel = _connect(uri);
      _channel = channel;
      await channel.ready;
    } catch (_) {
      _scheduleRetry();
      return;
    }
    if (_closed) {
      unawaited(channel.sink.close());
      return;
    }
    onStatus(const LinkStatus(LinkPhase.connected));
    _ping?.cancel();
    _ping = Timer.periodic(pingEvery, (_) {
      try {
        channel.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        // The done handler deals with a broken link.
      }
    });
    var ended = false;
    void end() {
      if (ended) return;
      ended = true;
      _ping?.cancel();
      if (_closed) return;
      if (channel.closeCode == unauthorizedCloseCode) {
        _closed = true;
        onStatus(const LinkStatus(LinkPhase.unauthorized));
        onUnauthorized();
        return;
      }
      _scheduleRetry();
    }

    _sub = channel.stream.listen(
      (raw) {
        _failures = 0;
        onFrame(LiveFrame.parse(raw));
      },
      onError: (Object _) => end(),
      onDone: end,
    );
  }

  void _scheduleRetry() {
    if (_closed) return;
    final delay = backoffFor(_failures);
    _failures++;
    onStatus(
      LinkStatus(LinkPhase.reconnecting, retryIn: delay, attempt: _failures),
    );
    _retry?.cancel();
    _retry = Timer(delay, _open);
  }

  /// Retry now (e.g. the person tapped the status chip).
  void retryNow() {
    if (_closed) return;
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _open();
  }

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    _ping?.cancel();
    await _sub?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Already gone.
    }
  }
}
