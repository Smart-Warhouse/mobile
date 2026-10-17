import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/l10n/labels.dart';
import '../../features/alerts/data/models/fleet_event.dart';
import '../../features/alerts/presentation/providers/alerts_controller.dart';

/// Bottom navigation over the five tabs.
class TabShell extends ConsumerWidget {
  const TabShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final criticalCount = ref.watch(
      alertsControllerProvider.select(
        (s) => s.events
            .take(50)
            .where((e) => e.severity == EventSeverity.critical)
            .length,
      ),
    );
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.truck),
            selectedIcon: const Icon(PhosphorIconsFill.truck),
            label: l10n.navFleet,
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.mapTrifold),
            selectedIcon: const Icon(PhosphorIconsFill.mapTrifold),
            label: l10n.navMap,
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.listChecks),
            selectedIcon: const Icon(PhosphorIconsFill.listChecks),
            label: l10n.navTasks,
          ),
          NavigationDestination(
            icon: const Icon(PhosphorIconsRegular.stack),
            selectedIcon: const Icon(PhosphorIconsFill.stack),
            label: l10n.navInventory,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: criticalCount > 0,
              label: Text('$criticalCount'),
              child: const Icon(PhosphorIconsRegular.bell),
            ),
            selectedIcon: const Icon(PhosphorIconsFill.bell),
            label: l10n.navAlerts,
          ),
        ],
      ),
    );
  }
}
