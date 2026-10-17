import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/realtime/live_controller.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/floor_app_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/models/fleet_event.dart';
import 'providers/alerts_controller.dart';

/// Filters for the alert list (client side, over the loaded feed).
class AlertFilter {
  const AlertFilter({this.severity, this.type, this.robotId});

  final EventSeverity? severity;
  final EventType? type;
  final String? robotId;

  bool matches(FleetEvent e) =>
      (severity == null || e.severity == severity) &&
      (type == null || e.type == type) &&
      (robotId == null || e.robotId == robotId);
}

/// Use case 4: live safety feed with filters (SF-13, UI-06).
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertFilter _filter = const AlertFilter();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(alertsControllerProvider);
    final robots = ref.watch(liveControllerProvider.select((s) => s.robots));
    final visible = state.events.where(_filter.matches).toList();

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsetsDirectional.only(end: Sp.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );

    return Scaffold(
      appBar: FloorAppBar(title: l10n.alertsTitle),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Sp.lg,
                vertical: Sp.sm,
              ),
              children: [
                chip(
                  l10n.filterAll,
                  _filter.severity == null && _filter.type == null,
                  () => setState(
                    () => _filter = AlertFilter(robotId: _filter.robotId),
                  ),
                ),
                for (final s in [
                  EventSeverity.critical,
                  EventSeverity.warning,
                  EventSeverity.info,
                ])
                  chip(
                    l10n.severity(s),
                    _filter.severity == s,
                    () => setState(
                      () => _filter = AlertFilter(
                        severity: _filter.severity == s ? null : s,
                        type: _filter.type,
                        robotId: _filter.robotId,
                      ),
                    ),
                  ),
                for (final ty in [
                  EventType.safety,
                  EventType.error,
                  EventType.info,
                ])
                  chip(
                    l10n.eventType(ty),
                    _filter.type == ty,
                    () => setState(
                      () => _filter = AlertFilter(
                        severity: _filter.severity,
                        type: _filter.type == ty ? null : ty,
                        robotId: _filter.robotId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Sp.lg),
            child: DropdownButtonFormField<String?>(
              initialValue: _filter.robotId,
              decoration: InputDecoration(
                prefixIcon: const Icon(PhosphorIconsRegular.truck),
                labelText: l10n.allRobots,
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.allRobots)),
                for (final r in robots)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (v) => setState(
                () => _filter = AlertFilter(
                  severity: _filter.severity,
                  type: _filter.type,
                  robotId: v,
                ),
              ),
            ),
          ),
          const SizedBox(height: Sp.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(alertsControllerProvider.notifier).refresh(),
              child: switch (state) {
                AlertsState(loading: true, events: []) => const LoadingView(),
                AlertsState(:final error?, events: []) => FailureView(
                  error: error,
                  onRetry: () =>
                      ref.read(alertsControllerProvider.notifier).refresh(),
                ),
                _ when visible.isEmpty => ListView(
                  children: [
                    const SizedBox(height: 120),
                    EmptyView(
                      message: l10n.alertsEmpty,
                      icon: PhosphorIconsRegular.bellSimple,
                    ),
                  ],
                ),
                _ => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Sp.sm),
                  itemBuilder: (_, i) => EventTile(event: visible[i]),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EventTile extends ConsumerWidget {
  const EventTile({super.key, required this.event});

  final FleetEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    final tone = t.severity(event.severity);
    final robotName = event.robotId == null
        ? l10n.fleetWide
        : ref
                  .watch(
                    liveControllerProvider.select(
                      (s) => s.robot(event.robotId!),
                    ),
                  )
                  ?.name ??
              event.robotId!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.soft,
                borderRadius: BorderRadius.circular(Sp.radiusSm),
              ),
              child: Icon(severityIcon(event.severity), color: tone.fg),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.event(event), style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '$robotName · ${Fmt.clock(event.createdAt)}',
                    style: text.bodySmall?.copyWith(color: t.text2),
                  ),
                  if (event.x != null && event.y != null)
                    Telemetry(
                      'x ${Fmt.fixed(event.x!, 2)}  y ${Fmt.fixed(event.y!, 2)} m',
                      style: text.bodySmall?.copyWith(color: t.text3),
                    ),
                ],
              ),
            ),
            Flexible(
              child: StatusBadge(
                tone: tone,
                label: l10n.severity(event.severity),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
