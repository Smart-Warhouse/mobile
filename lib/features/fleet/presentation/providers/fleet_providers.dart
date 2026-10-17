import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/result.dart';
import '../../../../core/realtime/live_controller.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../data/models/robot.dart';

/// Stop all / release (SF-11). State = a request is in flight.
class EstopController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<Result<FleetState>> setEngaged(bool engaged) async {
    state = true;
    final res = await ref.read(fleetRepositoryProvider).estop(engaged: engaged);
    if (!ref.mounted) return res;
    if (res case Ok(:final value)) {
      ref.read(liveControllerProvider.notifier).applyFleet(value);
    }
    state = false;
    return res;
  }
}

final estopControllerProvider = NotifierProvider<EstopController, bool>(
  EstopController.new,
);

/// Which actions a robot card offers, from its state (UI-02).
class RobotActions {
  const RobotActions({
    required this.pause,
    required this.resume,
    required this.goCharge,
    required this.reset,
    required this.drive,
  });

  final bool pause;
  final bool resume;
  final bool goCharge;
  final bool reset;
  final bool drive;

  bool get any => pause || resume || goCharge || reset || drive;

  static const none = RobotActions(
    pause: false,
    resume: false,
    goCharge: false,
    reset: false,
    drive: false,
  );

  /// Mirrors the server's `invalid_state` rules so the person is not
  /// offered a command that will be refused. While the fleet E-stop is
  /// engaged every command is refused (`fleet_estopped`).
  factory RobotActions.of(Robot r, {required bool fleetEstop}) {
    if (!r.enabled || !r.online || fleetEstop) return none;
    final m = r.mode;
    return RobotActions(
      pause: m == RobotMode.busy || m == RobotMode.idle,
      resume: m == RobotMode.paused,
      goCharge:
          m == RobotMode.idle || m == RobotMode.paused || m == RobotMode.busy,
      reset: m == RobotMode.safe || m == RobotMode.error,
      drive: m == RobotMode.idle || m == RobotMode.paused,
    );
  }
}

/// Robot commands from cards (pause/resume/charge/reset).
class RobotCommandController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  Future<Result<Robot>> send(String robotId, RobotCommand cmd) async {
    state = {...state, robotId};
    final res = await ref.read(fleetRepositoryProvider).command(robotId, cmd);
    if (ref.mounted) state = {...state}..remove(robotId);
    return res;
  }
}

/// State = ids of robots with a command in flight.
final robotCommandControllerProvider =
    NotifierProvider<RobotCommandController, Set<String>>(
      RobotCommandController.new,
    );
