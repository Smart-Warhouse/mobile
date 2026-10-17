import '../../../../core/json/json_reader.dart';

enum PalletStatus {
  stored('stored'),
  inTransit('in_transit'),
  reserved('reserved'),
  unknown('_unknown');

  const PalletStatus(this.wire);

  final String wire;

  static PalletStatus parse(String? wire) => values.firstWhere(
    (m) => m.wire == wire,
    orElse: () => PalletStatus.unknown,
  );
}

enum LocationType {
  rack('rack'),
  dockIn('dock_in'),
  dockOut('dock_out'),
  staging('staging'),
  charge('charge'),
  unknown('_unknown');

  const LocationType(this.wire);

  final String wire;

  static LocationType parse(String? wire) => values.firstWhere(
    (m) => m.wire == wire,
    orElse: () => LocationType.unknown,
  );
}

class Pallet {
  const Pallet({
    required this.id,
    required this.arucoId,
    required this.sku,
    required this.status,
    this.productName,
    this.quantity,
    this.weightG,
    this.locationId,
    this.locationCode,
  });

  final int id;
  final int? arucoId;
  final String sku;
  final String? productName;
  final int? quantity;
  final double? weightG;
  final int? locationId;
  final String? locationCode;
  final PalletStatus status;

  /// Only a stored pallet can get a new move task (`pallet_busy` otherwise).
  bool get isMovable => status == PalletStatus.stored;

  factory Pallet.fromJson(JsonReader r) => Pallet(
    id: r.reqInt('id'),
    arucoId: r.optInt('aruco_id'),
    sku: r.string('sku'),
    productName: r.optString('product_name'),
    quantity: r.optInt('quantity'),
    weightG: r.optDouble('weight_g'),
    locationId: r.optInt('location_id'),
    locationCode: r.optString('location_code'),
    status: PalletStatus.parse(r.optString('status')),
  );
}

class Location {
  const Location({
    required this.id,
    required this.code,
    required this.type,
    required this.x,
    required this.y,
    this.yaw = 0,
    this.level,
    this.heightMm,
    this.arucoId,
    this.nodeId,
    this.occupied = false,
    this.palletId,
  });

  final int id;
  final String code;
  final LocationType type;
  final double x;
  final double y;
  final double yaw;
  final int? level;
  final int? heightMm;
  final int? arucoId;
  final String? nodeId;
  final bool occupied;
  final int? palletId;

  factory Location.fromJson(JsonReader r) => Location(
    id: r.reqInt('id'),
    code: r.reqString('code'),
    type: LocationType.parse(r.optString('type')),
    x: r.dbl('x'),
    y: r.dbl('y'),
    yaw: r.dbl('yaw'),
    level: r.optInt('level'),
    heightMm: r.optInt('height_mm'),
    arucoId: r.optInt('aruco_id'),
    nodeId: r.optString('node_id'),
    occupied: r.boolean('occupied'),
    palletId: r.optInt('pallet_id'),
  );
}

class InventoryMove {
  const InventoryMove({
    required this.id,
    required this.palletId,
    this.fromCode,
    this.toCode,
    this.taskId,
    this.movedAt,
  });

  final int id;
  final int palletId;
  final String? fromCode;
  final String? toCode;
  final String? taskId;
  final DateTime? movedAt;

  factory InventoryMove.fromJson(JsonReader r) => InventoryMove(
    id: r.reqInt('id'),
    palletId: r.reqInt('pallet_id'),
    fromCode: r.optString('from_code'),
    toCode: r.optString('to_code'),
    taskId: r.optString('task_id'),
    movedAt: r.optDateTime('moved_at'),
  );
}
