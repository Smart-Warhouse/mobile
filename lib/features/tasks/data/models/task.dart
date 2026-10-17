import '../../../../core/json/json_reader.dart';

enum TaskStatus {
  queued('queued'),
  assigned('assigned'),
  toPickup('to_pickup'),
  picking('picking'),
  toDrop('to_drop'),
  dropping('dropping'),
  done('done'),
  failed('failed'),
  cancelled('cancelled'),
  unknown('_unknown');

  const TaskStatus(this.wire);

  final String wire;

  bool get isTerminal => this == done || this == failed || this == cancelled;

  static TaskStatus parse(String? wire) => values.firstWhere(
    (m) => m.wire == wire,
    orElse: () => TaskStatus.unknown,
  );
}

/// FR-01 move task.
class WarehouseTask {
  const WarehouseTask({
    required this.id,
    required this.status,
    required this.priority,
    this.type = 'move_pallet',
    this.palletId,
    this.palletSku,
    this.fromLocationId,
    this.fromCode,
    this.toLocationId,
    this.toCode,
    this.robotId,
    this.route = const [],
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.failReason,
    this.createdBy,
  });

  final String id;
  final String type;
  final int? palletId;
  final String? palletSku;
  final int? fromLocationId;
  final String? fromCode;
  final int? toLocationId;
  final String? toCode;
  final String? robotId;

  /// 1 (low) .. 5 (urgent).
  final int priority;
  final TaskStatus status;
  final List<String> route;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? failReason;
  final String? createdBy;

  bool get canCancel => !status.isTerminal && status != TaskStatus.unknown;

  factory WarehouseTask.fromJson(JsonReader r) => WarehouseTask(
    id: r.reqString('id'),
    type: r.string('type', orElse: 'move_pallet'),
    palletId: r.optInt('pallet_id'),
    palletSku: r.optString('pallet_sku'),
    fromLocationId: r.optInt('from_location_id'),
    fromCode: r.optString('from_code'),
    toLocationId: r.optInt('to_location_id'),
    toCode: r.optString('to_code'),
    robotId: r.optString('robot_id'),
    priority: (r.optInt('priority') ?? 2).clamp(1, 5),
    status: TaskStatus.parse(r.optString('status')),
    route: r.strings('route'),
    createdAt: r.optDateTime('created_at'),
    startedAt: r.optDateTime('started_at'),
    finishedAt: r.optDateTime('finished_at'),
    failReason: r.optString('fail_reason'),
    createdBy: r.optString('created_by'),
  );
}
