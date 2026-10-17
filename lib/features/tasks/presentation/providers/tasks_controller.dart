import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/realtime/live_controller.dart';
import '../../../../core/realtime/live_frame.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../auth/presentation/providers/session_controller.dart';
import '../../data/models/task.dart';

class TasksState {
  const TasksState({this.tasks = const [], this.loading = false, this.error});

  /// Newest first.
  final List<WarehouseTask> tasks;
  final bool loading;
  final ApiFailure? error;
}

/// Recent tasks with live status from WS `task` frames (FR-01, UI-03).
class TasksController extends Notifier<TasksState> {
  @override
  TasksState build() {
    final signedIn = ref.watch(
      sessionControllerProvider.select((s) => s is SignedIn),
    );
    if (!signedIn) return const TasksState();
    final sub = ref.watch(liveFrameBusProvider).stream.listen((f) {
      if (f is TaskFrame) upsert(f.task);
    });
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return const TasksState(loading: true);
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = TasksState(tasks: state.tasks, loading: true);
    final res = await ref.read(tasksRepositoryProvider).list(limit: 50);
    if (!ref.mounted) return;
    state = switch (res) {
      Ok(:final value) => TasksState(tasks: value.items),
      Err(:final failure) => TasksState(tasks: state.tasks, error: failure),
    };
  }

  void upsert(WarehouseTask t) {
    if (!ref.mounted) return;
    final list = [...state.tasks];
    final i = list.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      list[i] = t;
    } else {
      list.insert(0, t);
    }
    state = TasksState(tasks: list, loading: state.loading, error: state.error);
  }

  Future<Result<WarehouseTask>> create({
    required int palletId,
    required int toLocationId,
    required int priority,
  }) async {
    final res = await ref
        .read(tasksRepositoryProvider)
        .create(
          palletId: palletId,
          toLocationId: toLocationId,
          priority: priority,
        );
    if (res case Ok(:final value)) upsert(value);
    return res;
  }

  Future<Result<WarehouseTask>> cancel(String id) async {
    final res = await ref.read(tasksRepositoryProvider).cancel(id);
    if (res case Ok(:final value)) upsert(value);
    return res;
  }
}

final tasksControllerProvider = NotifierProvider<TasksController, TasksState>(
  TasksController.new,
);
