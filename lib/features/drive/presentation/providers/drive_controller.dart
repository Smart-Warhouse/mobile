import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/realtime/live_controller.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../fleet/data/fleet_repository.dart';
import '../../domain/teleop_loop.dart';

class DriveState {
  const DriveState({
    this.robotId,
    this.manual = false,
    this.switching = false,
    this.deadman = false,
    this.command = TeleopCommand.stop,
    this.limitedV,
    this.error,
  });

  final String? robotId;

  /// The robot was switched to manual by this screen.
  final bool manual;
  final bool switching;
  final bool deadman;
  final TeleopCommand command;

  /// Last speed after the server clamp (SF-07).
  final double? limitedV;
  final ApiFailure? error;

  DriveState copyWith({
    String? robotId,
    bool? manual,
    bool? switching,
    bool? deadman,
    TeleopCommand? command,
    double? limitedV,
    ApiFailure? error,
    bool clearError = false,
  }) => DriveState(
    robotId: robotId ?? this.robotId,
    manual: manual ?? this.manual,
    switching: switching ?? this.switching,
    deadman: deadman ?? this.deadman,
    command: command ?? this.command,
    limitedV: limitedV ?? this.limitedV,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Manual drive (FR-10, UI-08). Auto-disposed with the screen: disposing
/// releases the dead-man loop and switches the robot back to auto.
class DriveController extends Notifier<DriveState> {
  late TeleopLoop _loop;
  late FleetRepository _repo;

  /// Robot this screen switched to manual (mirrors state for teardown,
  /// when `state` must no longer be read).
  String? _manualRobotId;

  @override
  DriveState build() {
    _repo = ref.read(fleetRepositoryProvider);
    _loop = TeleopLoop(send: _send);
    // A fleet E-stop drops the dead-man immediately.
    ref.listen(liveControllerProvider.select((s) => s.estopEngaged), (_, on) {
      if (on) setDeadman(false);
    });
    ref.onDispose(() {
      // Leaving the screen: stop sending, then back to auto.
      final id = _manualRobotId;
      _loop.dispose();
      _manualRobotId = null;
      if (id != null) unawaited(_repo.setMode(id, manual: false));
    });
    return const DriveState();
  }

  Future<void> _send(TeleopCommand cmd) async {
    final id = _manualRobotId;
    if (id == null) return;
    final res = await _repo.teleop(id, v: cmd.v, w: cmd.w, lift: cmd.lift);
    if (!ref.mounted) return;
    switch (res) {
      case Ok(:final value):
        state = state.copyWith(limitedV: value.limitedV, clearError: true);
      case Err(:final failure):
        state = state.copyWith(error: failure);
        // A refused command (E-stop, offline, not manual) ends the drive.
        if (failure is ServerFailure) setDeadman(false);
    }
  }

  Future<void> selectRobot(String id) async {
    if (state.robotId == id) return;
    await leaveManual();
    state = DriveState(robotId: id);
  }

  Future<Result<void>> enterManual() async {
    final id = state.robotId;
    if (id == null) return const Ok(null);
    state = state.copyWith(switching: true, clearError: true);
    final res = await _repo.setMode(id, manual: true);
    if (res is Ok) _manualRobotId = id;
    if (!ref.mounted) return const Ok(null);
    state = state.copyWith(switching: false, manual: res is Ok);
    return res.when(ok: (_) => const Ok(null), err: Err.new);
  }

  Future<void> leaveManual() async {
    setDeadman(false);
    final id = state.robotId;
    if (id == null || !state.manual) return;
    state = state.copyWith(switching: true);
    _manualRobotId = null;
    await _repo.setMode(id, manual: false);
    if (!ref.mounted) return;
    state = state.copyWith(switching: false, manual: false);
  }

  void setDeadman(bool held) {
    if (!ref.mounted) return;
    if (held && state.manual) {
      _loop.command = state.command;
      _loop.engage();
    } else {
      _loop.release();
    }
    state = state.copyWith(
      deadman: held && state.manual,
      command: held && state.manual ? state.command : TeleopCommand.stop,
    );
  }

  void setStick(double dx, double dy) {
    final cmd = TeleopCommand.fromStick(dx, dy, lift: state.command.lift);
    _loop.command = cmd;
    state = state.copyWith(command: cmd);
  }

  void setLift(int lift) {
    final cmd = state.command.withLift(lift);
    _loop.command = cmd;
    state = state.copyWith(command: cmd);
  }
}

final driveControllerProvider =
    NotifierProvider.autoDispose<DriveController, DriveState>(
      DriveController.new,
    );
