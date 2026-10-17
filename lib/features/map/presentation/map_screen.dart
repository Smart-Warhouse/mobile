import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/realtime/live_controller.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/floor_app_bar.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../fleet/presentation/widgets/robot_card.dart';
import '../data/models/warehouse_map.dart';
import '../domain/map_transform.dart';
import 'map_painter.dart';

/// `GET /api/map`, cached for the session (the layout is static).
final warehouseMapProvider = FutureProvider<WarehouseMap>((ref) async {
  final res = await ref.watch(mapRepositoryProvider).map();
  return res.unwrap();
});

/// Use case 5: mini live map. Tap a robot → its card.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.sw;
    final mapAsync = ref.watch(warehouseMapProvider);
    final robots = ref.watch(liveControllerProvider.select((s) => s.robots));
    final reservations = ref.watch(
      liveControllerProvider.select((s) => s.reservations),
    );

    return Scaffold(
      appBar: FloorAppBar(
        title: l10n.mapTitle,
        actions: [
          IconButton(
            tooltip: l10n.retry,
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => ref.invalidate(warehouseMapProvider),
          ),
        ],
      ),
      body: mapAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => FailureView(
          error: e,
          onRetry: () => ref.invalidate(warehouseMapProvider),
        ),
        data: (map) => Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Sp.lg,
                Sp.sm,
                Sp.lg,
                0,
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.handTap, size: 16, color: t.text3),
                  const SizedBox(width: Sp.xs),
                  Flexible(
                    child: Text(
                      l10n.mapHint,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.text3),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // The map is always LTR: x grows to the right.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    final tx = MapTransform(
                      mapWidthM: map.widthM,
                      mapHeightM: map.heightM,
                      canvas: size,
                    );
                    return InteractiveViewer(
                      maxScale: 6,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final hit = hitRobot(robots, tx, d.localPosition);
                          if (hit == null) return;
                          setState(() => _selected = hit.id);
                          showRobotSheet(context, hit.id);
                        },
                        child: CustomPaint(
                          size: size,
                          painter: WarehouseMapPainter(
                            map: map,
                            robots: robots,
                            reservedSegments: {
                              for (final r in reservations) r.segmentId,
                            },
                            tokens: t,
                            selectedRobotId: _selected,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
