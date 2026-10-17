import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../auth/presentation/providers/session_controller.dart';
import '../data/models/pallet_models.dart';
import 'pallet_search_view.dart';
import 'providers/pallet_providers.dart';

/// Use case 8: where a pallet is and how it moved (UI-04).
class PalletDetailScreen extends ConsumerWidget {
  const PalletDetailScreen({super.key, required this.palletId, this.pallet});

  final int palletId;

  /// Passed from the list; null when opened by path.
  final Pallet? pallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = pallet;
    return Scaffold(
      appBar: AppBar(title: Text(p?.sku ?? '#$palletId')),
      body: p != null
          ? _Body(pallet: p)
          : ref
                .watch(palletByIdProvider(palletId))
                .when(
                  loading: () => const LoadingView(),
                  error: (e, _) => FailureView(
                    error: e,
                    onRetry: () => ref.invalidate(palletByIdProvider(palletId)),
                  ),
                  data: (found) => found == null
                      ? EmptyView(message: l10n.errPalletNotFound)
                      : _Body(pallet: found),
                ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.pallet});

  final Pallet pallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final canOperate = ref.watch(canOperateProvider);
    final moves = ref.watch(palletMovesProvider(pallet.id));

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: t.text2),
            ),
          ),
          Text(value, style: text.bodyMedium),
        ],
      ),
    );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(palletMovesProvider(pallet.id).future),
      child: ListView(
        padding: const EdgeInsets.all(Sp.lg),
        children: [
          Card(child: PalletTile(pallet: pallet)),
          const SizedBox(height: Sp.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                children: [
                  row(
                    l10n.palletLocation,
                    pallet.locationCode ?? l10n.noLocation,
                  ),
                  if (pallet.quantity != null)
                    row(l10n.palletQty, '${pallet.quantity}'),
                  if (pallet.weightG != null)
                    row(
                      l10n.palletWeight,
                      l10n.weightValue(Fmt.fixed(pallet.weightG!, 0)),
                    ),
                  if (pallet.arucoId != null)
                    row(l10n.palletAruco, '${pallet.arucoId}'),
                ],
              ),
            ),
          ),
          if (canOperate && pallet.isMovable) ...[
            const SizedBox(height: Sp.md),
            FilledButton.icon(
              icon: const Icon(PhosphorIconsRegular.arrowsLeftRight),
              label: Text(l10n.palletMove),
              onPressed: () => context.push(Routes.move, extra: pallet),
            ),
          ],
          const SizedBox(height: Sp.xl),
          Text(l10n.palletHistory, style: text.titleMedium),
          const SizedBox(height: Sp.sm),
          moves.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Sp.xl),
              child: LoadingView(),
            ),
            error: (e, _) => FailureView(
              error: e,
              onRetry: () => ref.invalidate(palletMovesProvider(pallet.id)),
            ),
            data: (list) => list.isEmpty
                ? EmptyView(
                    message: l10n.palletHistoryEmpty,
                    icon: PhosphorIconsRegular.clockCounterClockwise,
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final m in list)
                          ListTile(
                            leading: const Icon(
                              PhosphorIconsRegular.arrowsLeftRight,
                            ),
                            title: Text(
                              l10n.taskFromTo(
                                m.fromCode ?? '?',
                                m.toCode ?? '?',
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (m.taskId != null) l10n.moveTask(m.taskId!),
                                if (m.movedAt != null) Fmt.dateTime(m.movedAt!),
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
