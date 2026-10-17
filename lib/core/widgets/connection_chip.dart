import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/labels.dart';
import '../realtime/live_controller.dart';
import '../realtime/live_socket.dart';
import '../theme/sw_tokens.dart';
import 'status_badge.dart';

/// Live-link status for the app bar. Tap while reconnecting = retry now.
class ConnectionChip extends ConsumerWidget {
  const ConnectionChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(liveControllerProvider.select((s) => s.link));
    final l10n = context.l10n;
    final t = context.sw;
    final (tone, icon, label) = switch (link.phase) {
      LinkPhase.connected => (
        t.successTone,
        PhosphorIconsFill.broadcast,
        l10n.linkConnected,
      ),
      LinkPhase.connecting => (
        t.warningTone,
        PhosphorIconsRegular.circleNotch,
        l10n.linkConnecting,
      ),
      LinkPhase.reconnecting => (
        t.warningTone,
        PhosphorIconsRegular.arrowsClockwise,
        l10n.linkReconnecting('${link.retryIn?.inSeconds ?? 0}'),
      ),
      LinkPhase.unauthorized || LinkPhase.closed => (
        t.dangerTone,
        PhosphorIconsRegular.wifiSlash,
        l10n.linkOffline,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: link.phase == LinkPhase.reconnecting
            ? () => ref.read(liveControllerProvider.notifier).retryNow()
            : null,
        child: StatusBadge(tone: tone, icon: icon, label: label, dense: true),
      ),
    );
  }
}
