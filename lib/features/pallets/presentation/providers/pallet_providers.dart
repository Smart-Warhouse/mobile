import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/live_controller.dart';
import '../../../../core/realtime/live_frame.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../data/models/pallet_models.dart';

/// Debounced inventory search (`GET /api/pallets?q=`). One instance per
/// screen ([scope]) so the inventory tab and the move flow do not share
/// a query.
class PalletSearch extends Notifier<AsyncValue<List<Pallet>>> {
  PalletSearch(this.scope);

  final String scope;

  static const debounce = Duration(milliseconds: 300);

  Timer? _debounce;
  String _query = '';
  int _seq = 0;

  String get query => _query;

  @override
  AsyncValue<List<Pallet>> build() {
    ref.onDispose(() => _debounce?.cancel());
    final sub = ref.watch(liveFrameBusProvider).stream.listen((f) {
      if (f is InventoryFrame && f.pallet != null) _patch(f.pallet!);
    });
    ref.onDispose(sub.cancel);
    Future.microtask(() => _run(_query));
    return const AsyncLoading();
  }

  void search(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => _run(q));
  }

  Future<void> refresh() => _run(_query);

  Future<void> _run(String q) async {
    if (!ref.mounted) return;
    final seq = ++_seq;
    // Keep showing the previous results while the new query runs.
    if (!state.hasValue) state = const AsyncLoading<List<Pallet>>();
    final res = await ref.read(palletsRepositoryProvider).search(q);
    if (!ref.mounted || seq != _seq) return;
    state = res.when(
      ok: AsyncData.new,
      err: (f) => AsyncError(f, StackTrace.current),
    );
  }

  void _patch(Pallet p) {
    final list = state.value;
    if (list == null) return;
    final i = list.indexWhere((x) => x.id == p.id);
    if (i < 0) return;
    state = AsyncData([...list]..[i] = p);
  }
}

final palletSearchProvider = NotifierProvider.autoDispose
    .family<PalletSearch, AsyncValue<List<Pallet>>, String>(PalletSearch.new);

/// `GET /api/pallets/{id}/moves` (UI-04). Refreshes when the pallet moves.
final palletMovesProvider = FutureProvider.autoDispose
    .family<List<InventoryMove>, int>((ref, id) async {
      final sub = ref.watch(liveFrameBusProvider).stream.listen((f) {
        if (f is InventoryFrame && f.move?.palletId == id) ref.invalidateSelf();
      });
      ref.onDispose(sub.cancel);
      final res = await ref.read(palletsRepositoryProvider).moves(id);
      return res.unwrap();
    });

/// The contract has no `GET /api/pallets/{id}`; a detail opened without the
/// pallet in hand (deep link, refresh) finds it in the full list.
final palletByIdProvider = FutureProvider.autoDispose.family<Pallet?, int>((
  ref,
  id,
) async {
  final res = await ref.read(palletsRepositoryProvider).search('');
  for (final p in res.unwrap()) {
    if (p.id == id) return p;
  }
  return null;
});

/// All locations (move destinations).
final locationsProvider = FutureProvider.autoDispose<List<Location>>((
  ref,
) async {
  final res = await ref.read(palletsRepositoryProvider).locations();
  return res.unwrap();
});
