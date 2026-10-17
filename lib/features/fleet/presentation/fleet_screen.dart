import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/realtime/live_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/floor_app_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/providers/session_controller.dart';
import 'widgets/robot_card.dart';

/// Use case 3: the fleet at a glance, from WS snapshots.
class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final live = ref.watch(liveControllerProvider);
    final canOperate = ref.watch(canOperateProvider);
    final fleet = live.fleet;
    final t = context.sw;

    return Scaffold(
      appBar: FloorAppBar(
        title: l10n.fleetTitle,
        actions: [
          if (canOperate)
            IconButton(
              tooltip: l10n.cmdDrive,
              icon: const Icon(PhosphorIconsRegular.gameController),
              onPressed: () => context.push(Routes.driveOf(null)),
            ),
        ],
      ),
      body: live.robots.isEmpty
          ? (live.lastSnapshotAt == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LoadingView(),
                      const SizedBox(height: Sp.lg),
                      Text(l10n.fleetEmpty, style: TextStyle(color: t.text2)),
                    ],
                  )
                : EmptyView(message: l10n.fleetEmpty))
          : ListView(
              padding: const EdgeInsets.all(Sp.lg),
              children: [
                if (fleet != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.md),
                    child: Wrap(
                      spacing: Sp.sm,
                      runSpacing: Sp.sm,
                      children: [
                        StatusBadge(
                          tone: fleet.robotsOnline < fleet.robotsTotal
                              ? t.warningTone
                              : t.successTone,
                          icon: PhosphorIconsRegular.truck,
                          label: l10n.fleetSummary(
                            '${fleet.robotsOnline}',
                            '${fleet.robotsTotal}',
                          ),
                        ),
                        StatusBadge(
                          tone: t.neutral,
                          icon: PhosphorIconsRegular.hourglass,
                          label: l10n.fleetQueued('${fleet.queuedTasks}'),
                        ),
                        StatusBadge(
                          tone: t.accentTone,
                          icon: PhosphorIconsRegular.listChecks,
                          label: l10n.fleetActive('${fleet.activeTasks}'),
                        ),
                      ],
                    ),
                  ),
                for (final r in live.robots) ...[
                  RobotCard(robot: r),
                  const SizedBox(height: Sp.md),
                ],
              ],
            ),
    );
  }
}
