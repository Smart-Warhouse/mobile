import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../features/alerts/data/models/fleet_event.dart';
import '../../features/fleet/data/models/robot.dart';
import '../../features/tasks/data/models/task.dart';
import '../theme/sw_tokens.dart';

/// Colour + icon + words: status is never colour alone
/// (docs/05-design-system.md rule 4).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.tone,
    required this.label,
    this.icon,
    this.dense = false,
  });

  final Tone tone;
  final String label;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: dense ? Sp.sm : Sp.md,
        vertical: dense ? 2 : Sp.xs,
      ),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 14 : 16, color: tone.fg),
            const SizedBox(width: Sp.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tone.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension ToneX on SwTokens {
  Tone get neutral => Tone(text2, surface2);
  Tone get accentTone => Tone(accent, surface2);
  Tone get successTone => Tone(success, successSoft);
  Tone get warningTone => Tone(warning, warningSoft);
  Tone get dangerTone => Tone(danger, dangerSoft);
  Tone get infoTone => Tone(info, infoSoft);

  /// idle = text-2, busy = accent, charging = info, paused/manual = warning,
  /// safe/estop/error/offline = danger.
  Tone robotMode(RobotMode m) => switch (m) {
    RobotMode.idle || RobotMode.unknown => neutral,
    RobotMode.busy => accentTone,
    RobotMode.charging => infoTone,
    RobotMode.paused || RobotMode.manual => warningTone,
    RobotMode.safe ||
    RobotMode.estop ||
    RobotMode.error ||
    RobotMode.offline => dangerTone,
  };

  Tone safety(SafetyState s) => switch (s) {
    SafetyState.normal || SafetyState.unknown => successTone,
    SafetyState.slow => warningTone,
    SafetyState.stop || SafetyState.safe || SafetyState.estop => dangerTone,
  };

  Tone severity(EventSeverity s) => switch (s) {
    EventSeverity.critical => dangerTone,
    EventSeverity.warning => warningTone,
    EventSeverity.info || EventSeverity.unknown => infoTone,
  };

  Tone taskStatus(TaskStatus s) => switch (s) {
    TaskStatus.done => successTone,
    TaskStatus.failed => dangerTone,
    TaskStatus.cancelled || TaskStatus.unknown => neutral,
    TaskStatus.queued => neutral,
    _ => accentTone,
  };

  Color battery(double pct) => pct < 8
      ? danger
      : pct < 15
      ? warning
      : success;
}

IconData robotModeIcon(RobotMode m) => switch (m) {
  RobotMode.idle => PhosphorIconsRegular.pause,
  RobotMode.busy => PhosphorIconsRegular.truck,
  RobotMode.charging => PhosphorIconsRegular.lightning,
  RobotMode.paused => PhosphorIconsRegular.pauseCircle,
  RobotMode.manual => PhosphorIconsRegular.gameController,
  RobotMode.safe => PhosphorIconsRegular.shieldWarning,
  RobotMode.estop => PhosphorIconsFill.octagon,
  RobotMode.error => PhosphorIconsRegular.warningCircle,
  RobotMode.offline => PhosphorIconsRegular.wifiSlash,
  RobotMode.unknown => PhosphorIconsRegular.question,
};

IconData batteryIcon(double pct) => pct < 8
    ? PhosphorIconsRegular.batteryWarning
    : pct < 35
    ? PhosphorIconsRegular.batteryLow
    : pct < 75
    ? PhosphorIconsRegular.batteryMedium
    : PhosphorIconsRegular.batteryHigh;

IconData severityIcon(EventSeverity s) => switch (s) {
  EventSeverity.critical => PhosphorIconsFill.warning,
  EventSeverity.warning => PhosphorIconsRegular.warning,
  _ => PhosphorIconsRegular.info,
};
