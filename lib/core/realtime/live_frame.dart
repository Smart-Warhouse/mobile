import 'dart:convert';

import '../../features/alerts/data/models/fleet_event.dart';
import '../../features/fleet/data/models/robot.dart';
import '../../features/pallets/data/models/pallet_models.dart';
import '../../features/tasks/data/models/task.dart';
import '../json/json_reader.dart';

/// A server → client frame on `/ws/live` (docs/02-api-contract.md §4):
/// `{ "type": ..., "data": ..., "ts": "..." }`.
sealed class LiveFrame {
  const LiveFrame();

  /// Never throws: anything unreadable becomes [UnknownFrame].
  static LiveFrame parse(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      final r = JsonReader.of(decoded, context: 'frame');
      final type = r.optString('type');
      final data = r.optObject('data');
      return switch (type) {
        'snapshot' when data != null => SnapshotFrame(
          robots: data.objects('robots', Robot.fromJson),
          reservations: data.objects('reservations', Reservation.fromJson),
          fleet: switch (data.optObject('fleet')) {
            final f? => FleetState.fromJson(f),
            null => null,
          },
        ),
        'task' when data != null => TaskFrame(WarehouseTask.fromJson(data)),
        'event' when data != null => EventFrame(FleetEvent.fromJson(data)),
        'inventory' when data != null => InventoryFrame(
          pallet: switch (data.optObject('pallet')) {
            final p? => Pallet.fromJson(p),
            null => null,
          },
          move: switch (data.optObject('move')) {
            final m? => InventoryMove.fromJson(m),
            null => null,
          },
        ),
        'pong' => const PongFrame(),
        _ => UnknownFrame(type),
      };
    } on JsonContractException {
      return const UnknownFrame(null);
    } on FormatException {
      return const UnknownFrame(null);
    }
  }
}

class SnapshotFrame extends LiveFrame {
  const SnapshotFrame({
    required this.robots,
    required this.reservations,
    this.fleet,
  });

  final List<Robot> robots;
  final List<Reservation> reservations;
  final FleetState? fleet;
}

class TaskFrame extends LiveFrame {
  const TaskFrame(this.task);
  final WarehouseTask task;
}

class EventFrame extends LiveFrame {
  const EventFrame(this.event);
  final FleetEvent event;
}

class InventoryFrame extends LiveFrame {
  const InventoryFrame({this.pallet, this.move});
  final Pallet? pallet;
  final InventoryMove? move;
}

class PongFrame extends LiveFrame {
  const PongFrame();
}

class UnknownFrame extends LiveFrame {
  const UnknownFrame(this.type);
  final String? type;
}
