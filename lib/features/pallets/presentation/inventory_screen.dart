import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/floor_app_bar.dart';
import 'pallet_search_view.dart';

/// Use case 8: pallet lookup.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: FloorAppBar(title: context.l10n.inventoryTitle),
    body: Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 0),
      child: PalletSearchView(
        scope: 'inventory',
        onPick: (p) => context.push(Routes.palletOf(p.id), extra: p),
      ),
    ),
  );
}
