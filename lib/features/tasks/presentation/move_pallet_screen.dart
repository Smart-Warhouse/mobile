import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../auth/presentation/providers/session_controller.dart';
import '../../pallets/data/models/pallet_models.dart';
import '../../pallets/presentation/pallet_search_view.dart';
import '../../pallets/presentation/providers/pallet_providers.dart';
import 'providers/tasks_controller.dart';

/// Destinations a pallet may be sent to: free, not where it already is,
/// and not a charger.
List<Location> freeDestinations(List<Location> all, Pallet pallet) =>
    [
      for (final l in all)
        if (!l.occupied &&
            l.id != pallet.locationId &&
            l.type != LocationType.charge &&
            l.type != LocationType.unknown)
          l,
    ]..sort((a, b) {
      final c = a.type.index.compareTo(b.type.index);
      return c != 0 ? c : a.code.compareTo(b.code);
    });

/// Use case 6: move a pallet on the spot (FR-01): pallet → free
/// destination → priority → `POST /api/tasks`.
class MovePalletScreen extends ConsumerStatefulWidget {
  const MovePalletScreen({super.key, this.initialPallet});

  final Pallet? initialPallet;

  @override
  ConsumerState<MovePalletScreen> createState() => _MovePalletScreenState();
}

class _MovePalletScreenState extends ConsumerState<MovePalletScreen> {
  late Pallet? _pallet = widget.initialPallet;
  Location? _dest;
  int _priority = 2;
  bool _submitting = false;

  Future<void> _submit() async {
    final p = _pallet;
    final d = _dest;
    if (p == null || d == null) return;
    setState(() => _submitting = true);
    final res = await ref
        .read(tasksControllerProvider.notifier)
        .create(palletId: p.id, toLocationId: d.id, priority: _priority);
    if (!mounted) return;
    setState(() => _submitting = false);
    final l10n = context.l10n;
    res.when(
      ok: (task) {
        showSnack(context, l10n.taskCreated(task.id));
        context.pop();
      },
      err: (f) {
        showSnack(context, l10n.failure(f), error: true);
        // The destination may have been taken meanwhile.
        ref.invalidate(locationsProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final canOperate = ref.watch(canOperateProvider);
    final pallet = _pallet;

    Widget heading(int n, String label) => Padding(
      padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: t.accent,
            foregroundColor: t.accentOn,
            child: Text('$n', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: Sp.sm),
          Text(label, style: text.titleMedium),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newTaskTitle)),
      body: !canOperate
          ? const Center(child: ReadOnlyNote())
          : ListView(
              padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.xxl),
              children: [
                heading(1, l10n.stepPallet),
                if (pallet == null)
                  SizedBox(
                    height: 360,
                    child: PalletSearchView(
                      scope: 'move',
                      onPick: (p) => setState(() {
                        _pallet = p;
                        _dest = null;
                      }),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: const Icon(PhosphorIconsRegular.package),
                      title: Text(pallet.sku),
                      subtitle: Text(
                        [
                          ?pallet.productName,
                          pallet.locationCode ?? l10n.noLocation,
                        ].join(' · '),
                      ),
                      trailing: widget.initialPallet == null
                          ? TextButton(
                              onPressed: () => setState(() {
                                _pallet = null;
                                _dest = null;
                              }),
                              child: Text(l10n.change),
                            )
                          : null,
                    ),
                  ),
                if (pallet != null && !pallet.isMovable)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.sm),
                    child: Text(
                      l10n.palletNotMovable(l10n.palletStatus(pallet.status)),
                      style: text.bodyMedium?.copyWith(color: t.danger),
                    ),
                  ),
                if (pallet != null && pallet.isMovable) ...[
                  heading(2, l10n.stepDestination),
                  _DestinationPicker(
                    pallet: pallet,
                    selected: _dest,
                    onPick: (l) => setState(() => _dest = l),
                  ),
                  heading(3, l10n.stepPriority),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (var p = 1; p <= 5; p++)
                        ButtonSegment(
                          value: p,
                          label: Text(
                            l10n.priority(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (s) =>
                        setState(() => _priority = s.first),
                  ),
                  const SizedBox(height: Sp.xl),
                  FilledButton.icon(
                    onPressed: _dest == null || _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(PhosphorIconsRegular.paperPlaneTilt),
                    label: Text(l10n.submitTask),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DestinationPicker extends ConsumerWidget {
  const _DestinationPicker({
    required this.pallet,
    required this.selected,
    required this.onPick,
  });

  final Pallet pallet;
  final Location? selected;
  final ValueChanged<Location> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.sw;
    return ref
        .watch(locationsProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Sp.xl),
            child: LoadingView(),
          ),
          error: (e, _) => FailureView(
            error: e,
            onRetry: () => ref.invalidate(locationsProvider),
          ),
          data: (all) {
            final free = freeDestinations(all, pallet);
            if (free.isEmpty) return EmptyView(message: l10n.destinationEmpty);
            return Card(
              child: Column(
                children: [
                  for (final l in free)
                    ListTile(
                      selected: l.id == selected?.id,
                      selectedTileColor: t.surface2,
                      leading: Icon(
                        l.id == selected?.id
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.circle,
                        color: l.id == selected?.id ? t.accent : t.text3,
                      ),
                      title: Text(l.code),
                      subtitle: Text(l10n.locationType(l.type)),
                      onTap: () => onPick(l),
                    ),
                ],
              ),
            );
          },
        );
  }
}
