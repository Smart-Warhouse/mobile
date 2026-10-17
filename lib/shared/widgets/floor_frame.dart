import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/l10n/labels.dart';
import '../../core/realtime/live_controller.dart';
import '../../core/theme/sw_tokens.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/hold_to_stop_button.dart';
import '../../features/alerts/presentation/alert_banner.dart';
import '../../features/alerts/presentation/providers/alerts_controller.dart';
import '../../features/auth/presentation/providers/session_controller.dart';
import '../../features/fleet/data/models/robot.dart';
import '../../features/fleet/presentation/providers/fleet_providers.dart';
import '../../features/tasks/presentation/providers/tasks_controller.dart';

/// Wraps every signed-in screen: the STOP ALL bar is always at the bottom
/// (SF-11, UI-07), critical alerts drop in from the top (SF-13), and an
/// engaged fleet E-stop takes over the whole screen.
class FloorFrame extends ConsumerStatefulWidget {
  const FloorFrame({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FloorFrame> createState() => _FloorFrameState();
}

class _FloorFrameState extends ConsumerState<FloorFrame> {
  bool _overlayHidden = false;

  @override
  Widget build(BuildContext context) {
    // Keep the feeds alive for the whole session, whatever tab is shown.
    ref.watch(alertsControllerProvider.select((_) => 0));
    ref.watch(tasksControllerProvider.select((_) => 0));
    final fleet = ref.watch(liveControllerProvider.select((s) => s.fleet));
    final estop = fleet?.estop ?? false;
    ref.listen(liveControllerProvider.select((s) => s.estopEngaged), (
      prev,
      now,
    ) {
      // A new stop always shows full screen again.
      if (now && prev != true) setState(() => _overlayHidden = false);
    });

    final showStrip = estop && _overlayHidden;
    return Material(
      color: context.sw.bg,
      child: Stack(
        children: [
          Column(
            children: [
              if (showStrip)
                _EstopStrip(
                  onTap: () => setState(() => _overlayHidden = false),
                ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: showStrip,
                  removeBottom: true,
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.child),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AlertBanner(),
                      ),
                    ],
                  ),
                ),
              ),
              const StopAllBar(),
            ],
          ),
          if (estop && !_overlayHidden && fleet != null)
            Positioned.fill(
              child: EstopOverlay(
                fleet: fleet,
                onHide: () => setState(() => _overlayHidden = true),
              ),
            ),
        ],
      ),
    );
  }
}

/// The persistent STOP ALL bar. Hold 1 s → `POST /api/fleet/estop
/// {engaged: true}`.
class StopAllBar extends ConsumerWidget {
  const StopAllBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.sw;
    final canOperate = ref.watch(canOperateProvider);
    final busy = ref.watch(estopControllerProvider);
    return Container(
      color: t.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.sm),
          child: HoldToStopButton(
            label: l10n.stopAll,
            hint: l10n.stopAllHold,
            semanticsLabel: l10n.stopAllSemantics,
            enabled: canOperate,
            busy: busy,
            onDisabledPress: () =>
                showSnack(context, l10n.stopAllViewer, error: true),
            onFire: () async {
              final res = await ref
                  .read(estopControllerProvider.notifier)
                  .setEngaged(true);
              if (!context.mounted) return;
              res.when(
                ok: (_) => showSnack(context, l10n.stopAllSent),
                err: (f) => showSnack(
                  context,
                  '${l10n.stopAllFailed}\n${l10n.failure(f)}',
                  error: true,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EstopStrip extends StatelessWidget {
  const _EstopStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sw;
    return Material(
      color: t.stopFill,
      child: InkWell(
        onTap: onTap,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.lg,
              vertical: Sp.sm,
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.octagon, color: t.stopOn, size: 20),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Text(
                    context.l10n.estopStrip,
                    style: TextStyle(
                      color: t.stopOn,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen red state while the fleet E-stop is engaged.
class EstopOverlay extends ConsumerWidget {
  const EstopOverlay({super.key, required this.fleet, required this.onHide});

  final FleetState fleet;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final canOperate = ref.watch(canOperateProvider);
    final busy = ref.watch(estopControllerProvider);
    final onStyle = TextStyle(color: t.stopOn);

    Future<void> release() async {
      final ok = await confirmAction(
        context,
        title: l10n.estopReleaseConfirmTitle,
        body: l10n.estopReleaseConfirmBody,
        confirmLabel: l10n.estopRelease,
      );
      if (!ok || !context.mounted) return;
      final res = await ref
          .read(estopControllerProvider.notifier)
          .setEngaged(false);
      if (!context.mounted) return;
      res.when(
        ok: (_) => showSnack(context, l10n.estopReleased),
        err: (f) => showSnack(context, l10n.failure(f), error: true),
      );
    }

    return Material(
      key: const ValueKey('estop-overlay'),
      color: t.stopFill,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(PhosphorIconsFill.octagon, size: 96, color: t.stopOn),
              const SizedBox(height: Sp.lg),
              Semantics(
                liveRegion: true,
                header: true,
                child: Text(
                  l10n.estopEngagedTitle,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(
                    color: t.stopOn,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: Sp.md),
              Text(
                l10n.estopEngagedBody,
                textAlign: TextAlign.center,
                style: text.titleMedium?.merge(onStyle),
              ),
              if (fleet.estopBy != null)
                Text(
                  l10n.estopBy(fleet.estopBy!),
                  textAlign: TextAlign.center,
                  style: onStyle,
                ),
              if (fleet.estopAt != null)
                Text(
                  l10n.estopAt(Fmt.clock(fleet.estopAt!)),
                  textAlign: TextAlign.center,
                  style: onStyle,
                ),
              const Spacer(),
              if (canOperate)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.stopOn,
                    foregroundColor: t.stopFill,
                    minimumSize: const Size.fromHeight(Sp.bigTapTarget),
                  ),
                  onPressed: busy ? null : release,
                  icon: const Icon(PhosphorIconsRegular.lockOpen),
                  label: Text(l10n.estopRelease),
                )
              else
                Text(
                  l10n.estopReleaseViewer,
                  textAlign: TextAlign.center,
                  style: onStyle.copyWith(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: Sp.md),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: t.stopOn),
                onPressed: onHide,
                child: Text(l10n.estopMinimize),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
