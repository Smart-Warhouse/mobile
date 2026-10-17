import 'dart:async';

/// One manual-drive command for `POST /api/robots/{id}/teleop`.
class TeleopCommand {
  const TeleopCommand({required this.v, required this.w, required this.lift});

  /// m/s, clamped to ±[maxV].
  final double v;

  /// rad/s, clamped to ±[maxW].
  final double w;

  /// -1 down, 0 hold, 1 up.
  final int lift;

  static const maxV = 0.3;
  static const maxW = 1.0;
  static const stop = TeleopCommand(v: 0, w: 0, lift: 0);

  /// From a joystick deflection in [-1, 1] (screen frame: +dy is DOWN,
  /// +dx is RIGHT). Up = forward, right = turn clockwise (negative w).
  factory TeleopCommand.fromStick(double dx, double dy, {int lift = 0}) =>
      TeleopCommand(
        v: (-dy.clamp(-1.0, 1.0) * maxV).clamp(-maxV, maxV).toDouble(),
        w: (-dx.clamp(-1.0, 1.0) * maxW).clamp(-maxW, maxW).toDouble(),
        lift: lift.clamp(-1, 1),
      );

  TeleopCommand withLift(int l) => TeleopCommand(v: v, w: w, lift: l);

  bool get isStop => v == 0 && w == 0 && lift == 0;

  @override
  bool operator ==(Object other) =>
      other is TeleopCommand &&
      other.v == v &&
      other.w == w &&
      other.lift == lift;

  @override
  int get hashCode => Object.hash(v, w, lift);
}

/// Sends the current [command] every [period] (10 Hz) ONLY while the
/// dead-man's button is engaged (FR-10, UI-08).
///
/// - [engage] starts the loop (first send immediately).
/// - [release] stops it and sends one final [TeleopCommand.stop] so the
///   robot halts at once instead of waiting for its watchdog; after that
///   nothing more is sent.
/// - A tick is skipped while the previous request is still in flight, so a
///   slow network never builds a queue of stale commands.
class TeleopLoop {
  TeleopLoop({
    required this.send,
    this.period = const Duration(milliseconds: 100),
  });

  final Future<void> Function(TeleopCommand cmd) send;
  final Duration period;

  TeleopCommand command = TeleopCommand.stop;
  Timer? _timer;
  bool _inFlight = false;
  bool _disposed = false;

  bool get engaged => _timer != null;

  void engage() {
    if (_disposed || _timer != null) return;
    _tick();
    _timer = Timer.periodic(period, (_) => _tick());
  }

  void release() {
    final wasEngaged = _timer != null;
    _timer?.cancel();
    _timer = null;
    command = TeleopCommand.stop;
    if (wasEngaged && !_disposed) unawaited(send(TeleopCommand.stop));
  }

  void _tick() {
    if (_inFlight) return;
    _inFlight = true;
    send(command).whenComplete(() => _inFlight = false);
  }

  void dispose() {
    release();
    _disposed = true;
  }
}
