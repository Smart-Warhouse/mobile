import '../../../../core/json/json_reader.dart';

enum EventType {
  safety('safety'),
  error('error'),
  info('info'),
  unknown('_unknown');

  const EventType(this.wire);

  final String wire;

  static EventType parse(String? wire) =>
      values.firstWhere((m) => m.wire == wire, orElse: () => EventType.unknown);
}

enum EventSeverity {
  info('info'),
  warning('warning'),
  critical('critical'),
  unknown('_unknown');

  const EventSeverity(this.wire);

  final String wire;

  static EventSeverity parse(String? wire) => values.firstWhere(
    (m) => m.wire == wire,
    orElse: () => EventSeverity.unknown,
  );
}

/// An event from `GET /api/events` or a WS `event` frame (SF-13, UI-06).
class FleetEvent {
  const FleetEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.code,
    required this.createdAt,
    this.robotId,
    this.message,
    this.x,
    this.y,
  });

  final int id;
  final String? robotId;
  final EventType type;
  final EventSeverity severity;

  /// Contract §5 code, kept verbatim (unknown codes still display).
  final String code;
  final String? message;
  final double? x;
  final double? y;
  final DateTime createdAt;

  /// Codes that interrupt the person on the floor (banner + vibration) even
  /// when the server tags them below `critical`.
  static const alarmCodes = {
    'person_detected',
    'estop_pressed',
    'fleet_estop',
    'watchdog_timeout',
    'battery_critical',
    'robot_offline',
    'wifi_lost',
    'tof_stop',
  };

  bool get isCritical =>
      severity == EventSeverity.critical || alarmCodes.contains(code);

  factory FleetEvent.fromJson(JsonReader r) => FleetEvent(
    id: r.reqInt('id'),
    robotId: r.optString('robot_id'),
    type: EventType.parse(r.optString('type')),
    severity: EventSeverity.parse(r.optString('severity')),
    code: r.string('code', orElse: 'unknown'),
    message: r.optString('message'),
    x: r.optDouble('x'),
    y: r.optDouble('y'),
    createdAt:
        r.optDateTime('created_at') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}
