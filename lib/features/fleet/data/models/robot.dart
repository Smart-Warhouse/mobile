import '../../../../core/json/json_reader.dart';
import '../../../alerts/data/models/fleet_event.dart';

/// Robot `mode` (FR-06, UI-02).
enum RobotMode {
  idle('idle'),
  busy('busy'),
  charging('charging'),
  paused('paused'),
  manual('manual'),
  safe('safe'),
  estop('estop'),
  error('error'),
  offline('offline'),
  unknown('_unknown');

  const RobotMode(this.wire);

  final String wire;

  static RobotMode parse(String? wire) =>
      values.firstWhere((m) => m.wire == wire, orElse: () => RobotMode.unknown);
}

/// Robot `safety_state`.
enum SafetyState {
  normal('normal'),
  slow('slow'),
  stop('stop'),
  safe('safe'),
  estop('estop'),
  unknown('_unknown');

  const SafetyState(this.wire);

  final String wire;

  static SafetyState parse(String? wire) => values.firstWhere(
    (m) => m.wire == wire,
    orElse: () => SafetyState.unknown,
  );
}

/// A robot command for `POST /api/robots/{id}/cmd`.
enum RobotCommand {
  pause('pause'),
  resume('resume'),
  goCharge('go_charge'),
  reset('reset'),
  cancel('cancel');

  const RobotCommand(this.wire);

  final String wire;
}

class Robot {
  const Robot({
    required this.id,
    required this.name,
    required this.online,
    this.enabled = true,
    required this.mode,
    required this.safetyState,
    required this.batteryPct,
    required this.x,
    required this.y,
    required this.yaw,
    required this.speed,
    this.ip,
    this.forkHeightMm = 0,
    this.carryingPalletId,
    this.currentTaskId,
    this.route = const [],
    this.path = const [],
    this.lastEvent,
    this.lastSeen,
    this.simulated = false,
  });

  final String id;
  final String name;
  final String? ip;
  final bool online;

  /// False for a disabled spare (e.g. fl4): shown greyed out, no actions.
  /// Absent on older servers, read as enabled.
  final bool enabled;
  final RobotMode mode;
  final SafetyState safetyState;
  final double batteryPct;
  final double x;
  final double y;

  /// Radians, map frame (counter-clockwise from +x).
  final double yaw;

  /// m/s.
  final double speed;
  final int forkHeightMm;
  final int? carryingPalletId;
  final String? currentTaskId;
  final List<String> route;
  final List<(double, double)> path;
  final FleetEvent? lastEvent;
  final DateTime? lastSeen;
  final bool simulated;

  /// Mode as shown: an offline robot is offline whatever its last mode was.
  RobotMode get effectiveMode => online ? mode : RobotMode.offline;

  factory Robot.fromJson(JsonReader r) => Robot(
    id: r.reqString('id'),
    name: r.string('name', orElse: r.reqString('id')),
    ip: r.optString('ip'),
    online: r.boolean('online'),
    enabled: r.boolean('enabled', orElse: true),
    mode: RobotMode.parse(r.optString('mode')),
    safetyState: SafetyState.parse(r.optString('safety_state')),
    batteryPct: r.dbl('battery_pct').clamp(0, 100).toDouble(),
    x: r.dbl('x'),
    y: r.dbl('y'),
    yaw: r.dbl('yaw'),
    speed: r.dbl('speed'),
    forkHeightMm: r.optInt('fork_height_mm') ?? 0,
    carryingPalletId: r.optInt('carrying_pallet_id'),
    currentTaskId: r.optString('current_task_id'),
    route: r.strings('route'),
    path: r.points('path'),
    lastEvent: switch (r.optObject('last_event')) {
      final e? => _tryEvent(e),
      null => null,
    },
    lastSeen: r.optDateTime('last_seen'),
    simulated: r.boolean('simulated'),
  );

  static FleetEvent? _tryEvent(JsonReader r) {
    try {
      return FleetEvent.fromJson(r);
    } on JsonContractException {
      return null;
    }
  }
}

/// SF-11 fleet summary.
class FleetState {
  const FleetState({
    required this.estop,
    this.estopBy,
    this.estopAt,
    this.robotsOnline = 0,
    this.robotsTotal = 0,
    this.queuedTasks = 0,
    this.activeTasks = 0,
  });

  final bool estop;
  final String? estopBy;
  final DateTime? estopAt;
  final int robotsOnline;
  final int robotsTotal;
  final int queuedTasks;
  final int activeTasks;

  factory FleetState.fromJson(JsonReader r) => FleetState(
    estop: r.boolean('estop'),
    estopBy: r.optString('estop_by'),
    estopAt: r.optDateTime('estop_at'),
    robotsOnline: r.optInt('robots_online') ?? 0,
    robotsTotal: r.optInt('robots_total') ?? 0,
    queuedTasks: r.optInt('queued_tasks') ?? 0,
    activeTasks: r.optInt('active_tasks') ?? 0,
  );
}

/// SF-10 traffic lock on a lane segment.
class Reservation {
  const Reservation({
    required this.segmentId,
    required this.robotId,
    this.since,
  });

  final String segmentId;
  final String robotId;
  final DateTime? since;

  factory Reservation.fromJson(JsonReader r) => Reservation(
    segmentId: r.reqString('segment_id'),
    robotId: r.reqString('robot_id'),
    since: r.optDateTime('since'),
  );
}

/// `POST /api/robots/{id}/teleop` answer.
class TeleopAck {
  const TeleopAck({required this.accepted, this.limitedV});

  final bool accepted;

  /// Speed after the server clamp (SF-07), m/s.
  final double? limitedV;

  factory TeleopAck.fromJson(JsonReader r) => TeleopAck(
    accepted: r.boolean('accepted'),
    limitedV: r.optDouble('limited_v'),
  );
}
