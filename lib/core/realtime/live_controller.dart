import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/session_controller.dart';
import '../../features/fleet/data/models/robot.dart';
import '../network/server_url.dart';
import '../providers.dart';
import 'live_frame.dart';
import 'live_socket.dart';

class LiveState {
  const LiveState({
    this.link = LinkStatus.initial,
    this.robots = const [],
    this.reservations = const [],
    this.fleet,
    this.lastSnapshotAt,
  });

  final LinkStatus link;

  /// Latest snapshot robots, sorted by id.
  final List<Robot> robots;
  final List<Reservation> reservations;
  final FleetState? fleet;
  final DateTime? lastSnapshotAt;

  bool get estopEngaged => fleet?.estop ?? false;

  Robot? robot(String id) {
    for (final r in robots) {
      if (r.id == id) return r;
    }
    return null;
  }

  LiveState copyWith({
    LinkStatus? link,
    List<Robot>? robots,
    List<Reservation>? reservations,
    FleetState? fleet,
    DateTime? lastSnapshotAt,
  }) => LiveState(
    link: link ?? this.link,
    robots: robots ?? this.robots,
    reservations: reservations ?? this.reservations,
    fleet: fleet ?? this.fleet,
    lastSnapshotAt: lastSnapshotAt ?? this.lastSnapshotAt,
  );
}

/// Non-snapshot frames (`task`, `event`, `inventory`) fan out here so each
/// feature controller listens only to what it needs.
final liveFrameBusProvider = Provider<StreamController<LiveFrame>>((ref) {
  final c = StreamController<LiveFrame>.broadcast();
  ref.onDispose(c.close);
  return c;
});

/// Holds the `/ws/live` socket for the signed-in session (SV-10, 2 Hz).
class LiveController extends Notifier<LiveState> {
  LiveSocket? _socket;

  @override
  LiveState build() {
    final creds = ref.watch(
      sessionControllerProvider.select(
        (s) => s is SignedIn ? (s.baseUrl, s.token) : null,
      ),
    );
    if (creds == null) {
      return const LiveState(link: LinkStatus(LinkPhase.closed));
    }
    final socket = LiveSocket(
      uri: liveSocketUri(creds.$1, creds.$2),
      connect: ref.watch(channelFactoryProvider),
      onFrame: _onFrame,
      onStatus: (s) {
        if (ref.mounted) state = state.copyWith(link: s);
      },
      onUnauthorized: () =>
          ref.read(sessionControllerProvider.notifier).signOut(expired: true),
    );
    _socket = socket;
    ref.onDispose(socket.close);
    Future.microtask(socket.start);
    return const LiveState();
  }

  void _onFrame(LiveFrame frame) {
    if (!ref.mounted) return;
    switch (frame) {
      case SnapshotFrame(:final robots, :final reservations, :final fleet):
        final sorted = [...robots]..sort((a, b) => a.id.compareTo(b.id));
        state = state.copyWith(
          robots: sorted,
          reservations: reservations,
          fleet: fleet,
          lastSnapshotAt: DateTime.now(),
        );
      case PongFrame() || UnknownFrame():
        break;
      case TaskFrame() || EventFrame() || InventoryFrame():
        ref.read(liveFrameBusProvider).add(frame);
    }
  }

  /// Applies a FleetState returned by `POST /api/fleet/estop` immediately,
  /// without waiting for the next snapshot.
  void applyFleet(FleetState fleet) {
    state = state.copyWith(fleet: fleet);
  }

  void retryNow() => _socket?.retryNow();
}

final liveControllerProvider = NotifierProvider<LiveController, LiveState>(
  LiveController.new,
);
