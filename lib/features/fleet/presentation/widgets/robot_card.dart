import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/l10n/labels.dart';
import '../../../../core/realtime/live_controller.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/sw_tokens.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/session_controller.dart';
import '../../data/models/robot.dart';
import '../providers/fleet_providers.dart';

/// One robot at a glance (FR-06, UI-02): mode and safety with colour,
/// icon and words, battery, task, speed; actions by role and state.
class RobotCard extends ConsumerWidget {
  const RobotCard({super.key, required this.robot, this.highlighted = false});

  final Robot robot;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final canOperate = ref.watch(canOperateProvider);
    final estop = ref.watch(
      liveControllerProvider.select((s) => s.estopEngaged),
    );
    final inFlight = ref.watch(
      robotCommandControllerProvider.select((s) => s.contains(robot.id)),
    );
    final mode = robot.effectiveMode;
    final actions = RobotActions.of(robot, fleetEstop: estop);

    Future<void> send(RobotCommand cmd) async {
      final res = await ref
          .read(robotCommandControllerProvider.notifier)
          .send(robot.id, cmd);
      if (!context.mounted) return;
      res.when(
        ok: (_) => showSnack(context, l10n.cmdSent),
        err: (f) => showSnack(context, l10n.failure(f), error: true),
      );
    }

    final card = Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sp.radius),
        side: BorderSide(
          color: highlighted ? t.ring : t.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: robot.enabled ? t.lift : t.surface2,
                    borderRadius: BorderRadius.circular(Sp.radiusSm),
                  ),
                  child: Icon(
                    PhosphorIconsRegular.truck,
                    color: robot.enabled ? t.liftOn : t.text3,
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(robot.name, style: text.titleMedium),
                      Telemetry(
                        robot.id,
                        style: text.bodySmall?.copyWith(color: t.text3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.sm),
                Flexible(
                  child: robot.enabled
                      ? StatusBadge(
                          tone: t.robotMode(mode),
                          icon: robotModeIcon(mode),
                          label: l10n.mode(mode),
                        )
                      : StatusBadge(
                          tone: t.neutral,
                          icon: PhosphorIconsRegular.prohibit,
                          label: l10n.robotDisabled,
                        ),
                ),
              ],
            ),
            if (robot.enabled &&
                robot.online &&
                robot.safetyState != SafetyState.normal &&
                robot.safetyState != SafetyState.unknown) ...[
              const SizedBox(height: Sp.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(
                  tone: t.safety(robot.safetyState),
                  icon: PhosphorIconsRegular.shieldWarning,
                  label: l10n.safety(robot.safetyState),
                  dense: true,
                ),
              ),
            ],
            const SizedBox(height: Sp.md),
            Wrap(
              spacing: Sp.lg,
              runSpacing: Sp.sm,
              children: [
                _Metric(
                  icon: batteryIcon(robot.batteryPct),
                  iconColor: t.battery(robot.batteryPct),
                  label: l10n.robotBattery,
                  value: l10n.percentValue(Fmt.fixed(robot.batteryPct, 0)),
                ),
                _Metric(
                  icon: PhosphorIconsRegular.gauge,
                  label: l10n.robotSpeed,
                  value: l10n.speedValue(Fmt.fixed(robot.speed.abs(), 2)),
                ),
                _Metric(
                  icon: PhosphorIconsRegular.arrowsDownUp,
                  label: l10n.robotFork,
                  value: l10n.mmValue('${robot.forkHeightMm}'),
                ),
                _Metric(
                  icon: PhosphorIconsRegular.listChecks,
                  label: l10n.robotTask,
                  value: robot.currentTaskId ?? l10n.robotNoTask,
                ),
              ],
            ),
            if (robot.carryingPalletId != null) ...[
              const SizedBox(height: Sp.sm),
              Row(
                children: [
                  Icon(PhosphorIconsRegular.package, size: 16, color: t.text2),
                  const SizedBox(width: Sp.xs),
                  Text(
                    l10n.robotCarrying('${robot.carryingPalletId}'),
                    style: text.bodySmall?.copyWith(color: t.text2),
                  ),
                ],
              ),
            ],
            if (robot.lastEvent case final e?) ...[
              const SizedBox(height: Sp.sm),
              Row(
                children: [
                  Icon(
                    severityIcon(e.severity),
                    size: 16,
                    color: t.severity(e.severity).fg,
                  ),
                  const SizedBox(width: Sp.xs),
                  Expanded(
                    child: Text(
                      '${l10n.event(e)} · ${Fmt.clock(e.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: t.text2),
                    ),
                  ),
                ],
              ),
            ],
            if (robot.enabled) ...[
              const SizedBox(height: Sp.md),
              if (!canOperate)
                const ReadOnlyNote()
              else if (estop)
                Text(
                  l10n.cmdBlockedEstop,
                  style: text.bodySmall?.copyWith(color: t.danger),
                )
              else if (actions.any)
                Wrap(
                  spacing: Sp.sm,
                  runSpacing: Sp.sm,
                  children: [
                    if (actions.pause)
                      _ActionButton(
                        icon: PhosphorIconsRegular.pause,
                        label: l10n.cmdPause,
                        busy: inFlight,
                        onPressed: () => send(RobotCommand.pause),
                      ),
                    if (actions.resume)
                      _ActionButton(
                        icon: PhosphorIconsRegular.play,
                        label: l10n.cmdResume,
                        busy: inFlight,
                        onPressed: () => send(RobotCommand.resume),
                      ),
                    if (actions.goCharge)
                      _ActionButton(
                        icon: PhosphorIconsRegular.lightning,
                        label: l10n.cmdGoCharge,
                        busy: inFlight,
                        onPressed: () => send(RobotCommand.goCharge),
                      ),
                    if (actions.reset)
                      _ActionButton(
                        icon: PhosphorIconsRegular.arrowCounterClockwise,
                        label: l10n.cmdReset,
                        busy: inFlight,
                        onPressed: () async {
                          final ok = await confirmAction(
                            context,
                            title: l10n.cmdResetConfirmTitle(robot.name),
                            body: l10n.cmdResetConfirmBody,
                          );
                          if (ok) await send(RobotCommand.reset);
                        },
                      ),
                    if (actions.drive)
                      _ActionButton(
                        icon: PhosphorIconsRegular.gameController,
                        label: l10n.cmdDrive,
                        busy: false,
                        onPressed: () => context.push(Routes.driveOf(robot.id)),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
    return robot.enabled ? card : Opacity(opacity: 0.55, child: card);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? t.text2),
          const SizedBox(width: Sp.xs),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.busy,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy ? null : onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

/// Opens a robot's card in a bottom sheet (from the map).
Future<void> showRobotSheet(BuildContext context, String robotId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final robot = ref.watch(
            liveControllerProvider.select((s) => s.robot(robotId)),
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Sp.lg,
                0,
                Sp.lg,
                Sp.lg,
              ),
              child: robot == null
                  ? EmptyView(message: ctx.l10n.fleetEmpty)
                  : RobotCard(robot: robot),
            ),
          );
        },
      ),
    );
