import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/realtime/live_controller.dart';
import '../../../../core/realtime/live_frame.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../auth/presentation/providers/session_controller.dart';
import '../../data/models/fleet_event.dart';

/// Vibration for a critical alert. A seam so tests stay silent.
class Alarm {
  const Alarm();

  Future<void> ring() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

final alarmProvider = Provider<Alarm>((ref) => const Alarm());

class AlertsState {
  const AlertsState({
    this.events = const [],
    this.loading = false,
    this.error,
    this.banner,
  });

  /// Newest first.
  final List<FleetEvent> events;
  final bool loading;
  final ApiFailure? error;

  /// The critical event currently raised as an in-app banner.
  final FleetEvent? banner;

  AlertsState copyWith({
    List<FleetEvent>? events,
    bool? loading,
    ApiFailure? error,
    bool clearError = false,
    FleetEvent? banner,
    bool clearBanner = false,
  }) => AlertsState(
    events: events ?? this.events,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    banner: clearBanner ? null : (banner ?? this.banner),
  );
}

/// Live safety feed (SF-13, UI-06): history from `GET /api/events`, then
/// every WS `event` frame. Critical events raise a banner and vibrate.
class AlertsController extends Notifier<AlertsState> {
  static const cap = 300;

  @override
  AlertsState build() {
    final signedIn = ref.watch(
      sessionControllerProvider.select((s) => s is SignedIn),
    );
    if (!signedIn) return const AlertsState();
    final sub = ref.watch(liveFrameBusProvider).stream.listen((f) {
      if (f is EventFrame) _onLive(f.event);
    });
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return const AlertsState(loading: true);
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearError: true);
    final res = await ref.read(eventsRepositoryProvider).list(limit: 100);
    if (!ref.mounted) return;
    switch (res) {
      case Ok(:final value):
        state = state.copyWith(
          events: _merge(value.items, state.events),
          loading: false,
        );
      case Err(:final failure):
        state = state.copyWith(loading: false, error: failure);
    }
  }

  void _onLive(FleetEvent e) {
    if (!ref.mounted) return;
    if (state.events.any((x) => x.id == e.id)) return;
    final events = [e, ...state.events];
    state = state.copyWith(
      events: events.length > cap ? events.sublist(0, cap) : events,
      banner: e.isCritical ? e : null,
    );
    if (e.isCritical) unawaited(ref.read(alarmProvider).ring());
  }

  void dismissBanner() => state = state.copyWith(clearBanner: true);

  static List<FleetEvent> _merge(List<FleetEvent> a, List<FleetEvent> b) {
    final byId = <int, FleetEvent>{for (final e in b) e.id: e};
    for (final e in a) {
      byId[e.id] = e;
    }
    final out = byId.values.toList()
      ..sort((x, y) {
        final c = y.createdAt.compareTo(x.createdAt);
        return c != 0 ? c : y.id.compareTo(x.id);
      });
    return out.length > cap ? out.sublist(0, cap) : out;
  }
}

final alertsControllerProvider =
    NotifierProvider<AlertsController, AlertsState>(AlertsController.new);
