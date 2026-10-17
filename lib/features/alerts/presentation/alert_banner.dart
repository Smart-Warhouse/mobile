import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/realtime/live_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/sw_tokens.dart';
import 'providers/alerts_controller.dart';

/// In-app banner for the latest critical event (SF-13). Stays until
/// dismissed; tap opens the alert list.
class AlertBanner extends ConsumerWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(alertsControllerProvider.select((s) => s.banner));
    if (e == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.sw;
    final robotName = e.robotId == null
        ? l10n.fleetWide
        : ref
                  .watch(
                    liveControllerProvider.select((s) => s.robot(e.robotId!)),
                  )
                  ?.name ??
              e.robotId!;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(Sp.sm),
        child: Semantics(
          liveRegion: true,
          child: Material(
            key: const ValueKey('alert-banner'),
            color: t.stopFill,
            elevation: 6,
            borderRadius: BorderRadius.circular(Sp.radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(Sp.radius),
              onTap: () {
                ref.read(alertsControllerProvider.notifier).dismissBanner();
                context.go(Routes.alerts);
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Sp.lg,
                  Sp.md,
                  Sp.xs,
                  Sp.md,
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIconsFill.warning, color: t.stopOn, size: 28),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.event(e),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: t.stopOn,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            '$robotName · ${Fmt.clock(e.createdAt)}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: t.stopOn),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      color: t.stopOn,
                      icon: const Icon(PhosphorIconsRegular.x),
                      onPressed: () => ref
                          .read(alertsControllerProvider.notifier)
                          .dismissBanner(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
