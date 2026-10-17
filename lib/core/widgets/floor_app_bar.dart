import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../l10n/labels.dart';
import '../router/routes.dart';
import '../theme/sw_tokens.dart';
import 'connection_chip.dart';

/// App bar for the tab screens: title, live-link chip, settings.
class FloorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FloorAppBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title),
    actions: [
      const ConnectionChip(),
      ...actions,
      IconButton(
        tooltip: context.l10n.settingsTitle,
        icon: const Icon(PhosphorIconsRegular.gearSix),
        onPressed: () => context.push(Routes.settings),
      ),
      const SizedBox(width: Sp.xs),
    ],
  );
}
