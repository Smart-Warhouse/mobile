import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/realtime/live_controller.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/providers/session_controller.dart';
import '../../fleet/data/models/robot.dart';
import 'joystick.dart';
import 'providers/drive_controller.dart';

/// Use case 7: manual drive (FR-10, UI-08). Teleop is sent at 10 Hz only
/// while the dead-man's button is held; leaving the screen returns the
/// robot to auto (see [DriveController]).
class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key, this.initialRobotId});

  final String? initialRobotId;

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // App backgrounded or covered: drop the dead-man at once.
    _lifecycle = AppLifecycleListener(
      onInactive: _dropDeadman,
      onHide: _dropDeadman,
      onPause: _dropDeadman,
    );
    final id = widget.initialRobotId;
    if (id != null) {
      Future.microtask(
        () => ref.read(driveControllerProvider.notifier).selectRobot(id),
      );
    }
  }

  void _dropDeadman() {
    if (mounted) ref.read(driveControllerProvider.notifier).setDeadman(false);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final canOperate = ref.watch(canOperateProvider);
    final drive = ref.watch(driveControllerProvider);
    final ctrl = ref.read(driveControllerProvider.notifier);
    final robots = ref.watch(liveControllerProvider.select((s) => s.robots));
    final estop = ref.watch(
      liveControllerProvider.select((s) => s.estopEngaged),
    );
    final candidates = [
      for (final r in robots)
        if (r.enabled && r.online) r,
    ];
    final robot = drive.robotId == null
        ? null
        : ref.watch(
            liveControllerProvider.select((s) => s.robot(drive.robotId!)),
          );
    final canDrive = drive.manual && !estop && (robot?.online ?? false);

    if (!canOperate) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.driveTitle)),
        body: const Center(child: ReadOnlyNote()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.driveTitle)),
      body: ListView(
        // While driving, a joystick drag must never scroll the page.
        physics: drive.manual ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(Sp.lg),
        children: [
          DropdownButtonFormField<String>(
            initialValue: candidates.any((r) => r.id == drive.robotId)
                ? drive.robotId
                : null,
            decoration: InputDecoration(
              labelText: l10n.driveSelectRobot,
              prefixIcon: const Icon(PhosphorIconsRegular.truck),
            ),
            hint: Text(
              candidates.isEmpty ? l10n.driveNoRobots : l10n.driveSelectRobot,
            ),
            items: [
              for (final r in candidates)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: drive.deadman || drive.switching
                ? null
                : (id) {
                    if (id != null) ctrl.selectRobot(id);
                  },
          ),
          const SizedBox(height: Sp.md),
          if (estop)
            Text(
              l10n.cmdBlockedEstop,
              style: text.bodyMedium?.copyWith(color: t.danger),
            ),
          if (robot != null) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Sp.md,
              runSpacing: Sp.sm,
              children: [
                StatusBadge(
                  tone: t.robotMode(robot.effectiveMode),
                  icon: robotModeIcon(robot.effectiveMode),
                  label: l10n.mode(robot.effectiveMode),
                ),
                if (!drive.manual)
                  FilledButton.icon(
                    onPressed: drive.switching || estop || !robot.online
                        ? null
                        : () async {
                            final res = await ctrl.enterManual();
                            if (!context.mounted) return;
                            res.when(
                              ok: (_) {},
                              err: (f) => showSnack(
                                context,
                                l10n.failure(f),
                                error: true,
                              ),
                            );
                          },
                    icon: const Icon(PhosphorIconsRegular.gameController),
                    label: Text(l10n.driveEnterManual),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: drive.switching ? null : ctrl.leaveManual,
                    icon: const Icon(PhosphorIconsRegular.robot),
                    label: Text(l10n.driveBackToAuto),
                  ),
              ],
            ),
            const SizedBox(height: Sp.md),
            _Readouts(drive: drive, robot: robot),
            const SizedBox(height: Sp.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Joystick(
                  semanticsLabel: l10n.driveJoystick,
                  enabled: canDrive,
                  onChanged: ctrl.setStick,
                ),
                Column(
                  children: [
                    _HoldButton(
                      enabled: canDrive,
                      icon: PhosphorIconsRegular.arrowFatUp,
                      label: l10n.driveLiftUp,
                      onChanged: (held) => ctrl.setLift(held ? 1 : 0),
                    ),
                    const SizedBox(height: Sp.md),
                    _HoldButton(
                      enabled: canDrive,
                      icon: PhosphorIconsRegular.arrowFatDown,
                      label: l10n.driveLiftDown,
                      onChanged: (held) => ctrl.setLift(held ? -1 : 0),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Sp.lg),
            _DeadmanButton(
              enabled: canDrive,
              held: drive.deadman,
              onChanged: ctrl.setDeadman,
            ),
            const SizedBox(height: Sp.md),
            if (drive.error != null)
              Text(
                '${l10n.driveCmdFailed}: ${l10n.failure(drive.error!)}',
                style: text.bodySmall?.copyWith(color: t.danger),
              ),
            Text(l10n.driveSafetyNote, style: text.bodySmall),
            const SizedBox(height: Sp.xs),
            Text(
              l10n.driveExitNote,
              style: text.bodySmall?.copyWith(color: t.text2),
            ),
          ],
        ],
      ),
    );
  }
}

class _Readouts extends StatelessWidget {
  const _Readouts({required this.drive, required this.robot});

  final DriveState drive;
  final Robot robot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final style = text.titleSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.md),
        child: Wrap(
          spacing: Sp.lg,
          runSpacing: Sp.sm,
          children: [
            Text(
              l10n.driveCommanded(Fmt.fixed(drive.command.v.abs(), 2)),
              style: style,
            ),
            Text(
              l10n.driveLimited(
                drive.limitedV == null
                    ? '--'
                    : Fmt.fixed(drive.limitedV!.abs(), 2),
              ),
              style: style?.copyWith(color: t.warning),
            ),
            Text(
              '${l10n.robotSpeed}: ${l10n.speedValue(Fmt.fixed(robot.speed.abs(), 2))}',
              style: style,
            ),
            Text(
              '${l10n.robotFork}: ${l10n.mmValue('${robot.forkHeightMm}')}',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

/// Raw-pointer hold button: `true` on press, `false` on release/cancel.
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onChanged,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Listener(
        onPointerDown: enabled ? (_) => onChanged(true) : null,
        onPointerUp: enabled ? (_) => onChanged(false) : null,
        onPointerCancel: enabled ? (_) => onChanged(false) : null,
        child: Container(
          width: 88,
          height: 72,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Sp.radius),
            border: Border.all(color: t.border, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: enabled ? t.accent : t.text3),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: enabled ? t.text : t.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dead-man's switch: teleop flows only while a finger is on it.
class _DeadmanButton extends StatelessWidget {
  const _DeadmanButton({
    required this.enabled,
    required this.held,
    required this.onChanged,
  });

  final bool enabled;
  final bool held;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.sw;
    final fill = !enabled
        ? t.surface2
        : held
        ? t.success
        : t.lift;
    final on = !enabled
        ? t.text3
        : held
        ? t.statusOn
        : t.liftOn;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.driveDeadman,
      child: Listener(
        key: const ValueKey('deadman'),
        onPointerDown: enabled
            ? (_) {
                HapticFeedback.selectionClick();
                onChanged(true);
              }
            : null,
        onPointerUp: enabled ? (_) => onChanged(false) : null,
        onPointerCancel: enabled ? (_) => onChanged(false) : null,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(Sp.radius),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIconsFill.handPalm, color: on),
              const SizedBox(width: Sp.sm),
              Flexible(
                child: Text(
                  held ? l10n.driveDeadmanActive : l10n.driveDeadman,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: on,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
