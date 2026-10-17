import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/models/pallet_models.dart';
import 'providers/pallet_providers.dart';

/// Search field + results (SKU, name or ArUco id). Shared by the
/// inventory tab and the move flow.
class PalletSearchView extends ConsumerWidget {
  const PalletSearchView({
    super.key,
    required this.scope,
    required this.onPick,
  });

  final String scope;
  final ValueChanged<Pallet> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = palletSearchProvider(scope);
    final results = ref.watch(provider);
    return Column(
      children: [
        TextField(
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            hintText: l10n.palletSearchHint,
          ),
          onChanged: (q) => ref.read(provider.notifier).search(q),
          onSubmitted: (q) => ref.read(provider.notifier).search(q),
        ),
        const SizedBox(height: Sp.sm),
        Expanded(
          child: results.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) => FailureView(
              error: e,
              onRetry: () => ref.read(provider.notifier).refresh(),
            ),
            data: (list) => list.isEmpty
                ? EmptyView(
                    message: l10n.palletEmpty,
                    icon: PhosphorIconsRegular.stack,
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) => PalletTile(
                      pallet: list[i],
                      onTap: () => onPick(list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class PalletTile extends StatelessWidget {
  const PalletTile({super.key, required this.pallet, this.onTap});

  final Pallet pallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.sw;
    final tone = switch (pallet.status) {
      PalletStatus.stored => t.successTone,
      PalletStatus.inTransit => t.accentTone,
      PalletStatus.reserved => t.warningTone,
      PalletStatus.unknown => t.neutral,
    };
    return ListTile(
      onTap: onTap,
      leading: const Icon(PhosphorIconsRegular.package),
      title: Text(pallet.sku),
      subtitle: Text(
        [
          ?pallet.productName,
          pallet.locationCode ?? l10n.noLocation,
          if (pallet.arucoId != null) 'ArUco ${pallet.arucoId}',
        ].join(' · '),
      ),
      trailing: StatusBadge(
        tone: tone,
        label: l10n.palletStatus(pallet.status),
        dense: true,
      ),
    );
  }
}
