import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/l10n/labels.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/sw_tokens.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/floor_app_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/providers/session_controller.dart';
import '../data/models/task.dart';
import 'providers/tasks_controller.dart';

/// Use case 6 (list half): my tasks with live status, cancel.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _mine = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tasksControllerProvider);
    final me = ref.watch(currentUserProvider);
    final canOperate = ref.watch(canOperateProvider);
    final tasks = _mine
        ? state.tasks.where((x) => x.createdBy == me?.username).toList()
        : state.tasks;

    return Scaffold(
      appBar: FloorAppBar(title: l10n.tasksTitle),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.move),
              icon: const Icon(PhosphorIconsRegular.package),
              label: Text(l10n.taskNew),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.sm),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, label: Text(l10n.tasksMine)),
                      ButtonSegment(value: false, label: Text(l10n.tasksAll)),
                    ],
                    selected: {_mine},
                    onSelectionChanged: (s) => setState(() => _mine = s.first),
                  ),
                ),
              ],
            ),
          ),
          if (!canOperate)
            const Padding(
              padding: EdgeInsetsDirectional.only(
                start: Sp.lg,
                end: Sp.lg,
                bottom: Sp.sm,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ReadOnlyNote(),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(tasksControllerProvider.notifier).refresh(),
              child: switch (state) {
                TasksState(loading: true, tasks: []) => const LoadingView(),
                TasksState(:final error?, tasks: []) => FailureView(
                  error: error,
                  onRetry: () =>
                      ref.read(tasksControllerProvider.notifier).refresh(),
                ),
                _ when tasks.isEmpty => ListView(
                  children: [
                    const SizedBox(height: 120),
                    EmptyView(
                      message: l10n.tasksEmpty,
                      icon: PhosphorIconsRegular.listChecks,
                    ),
                  ],
                ),
                _ => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, 96),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Sp.sm),
                  itemBuilder: (_, i) =>
                      TaskTile(task: tasks[i], canOperate: canOperate),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, required this.canOperate});

  final WarehouseTask task;
  final bool canOperate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.sw;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Telemetry(task.id, style: text.titleSmall),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Text(
                    l10n.taskPallet(task.palletSku ?? '${task.palletId ?? ''}'),
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: StatusBadge(
                    tone: t.taskStatus(task.status),
                    label: l10n.taskStatus(task.status),
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.xs),
            Text(
              l10n.taskFromTo(task.fromCode ?? '?', task.toCode ?? '?'),
              style: text.bodyMedium,
            ),
            const SizedBox(height: Sp.xs),
            Wrap(
              spacing: Sp.md,
              children: [
                Text(
                  task.robotId == null
                      ? l10n.taskUnassigned
                      : l10n.taskRobot(task.robotId!),
                  style: text.bodySmall?.copyWith(color: t.text2),
                ),
                Text(
                  l10n.taskPriority(l10n.priority(task.priority)),
                  style: text.bodySmall?.copyWith(color: t.text2),
                ),
                if (task.createdAt != null)
                  Telemetry(
                    Fmt.clock(task.createdAt!),
                    style: text.bodySmall?.copyWith(color: t.text3),
                  ),
              ],
            ),
            if (task.failReason != null) ...[
              const SizedBox(height: Sp.xs),
              Text(
                l10n.taskFailReason(task.failReason!),
                style: text.bodySmall?.copyWith(color: t.danger),
              ),
            ],
            if (canOperate && task.canCancel)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(PhosphorIconsRegular.xCircle),
                  label: Text(l10n.taskCancel),
                  style: TextButton.styleFrom(foregroundColor: t.danger),
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: l10n.taskCancelConfirm(task.id),
                      destructive: true,
                      confirmLabel: l10n.taskCancel,
                    );
                    if (!ok) return;
                    final res = await ref
                        .read(tasksControllerProvider.notifier)
                        .cancel(task.id);
                    if (!context.mounted) return;
                    res.when(
                      ok: (_) => showSnack(context, l10n.taskCancelled),
                      err: (f) =>
                          showSnack(context, l10n.failure(f), error: true),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
