import 'package:flutter_test/flutter_test.dart';
import 'package:sw_floor/core/json/json_reader.dart';
import 'package:sw_floor/core/realtime/live_frame.dart';
import 'package:sw_floor/features/alerts/data/models/fleet_event.dart';
import 'package:sw_floor/features/auth/data/auth_repository.dart';
import 'package:sw_floor/features/auth/data/models/user.dart';
import 'package:sw_floor/features/fleet/data/models/robot.dart';
import 'package:sw_floor/features/map/data/models/warehouse_map.dart';
import 'package:sw_floor/features/pallets/data/models/pallet_models.dart';
import 'package:sw_floor/features/tasks/data/models/task.dart';

import '../support/contract_fixtures.dart';

void main() {
  group('contract shapes parse', () {
    test('User + role gating', () {
      final u = User.fromJson(JsonReader(Map.of(userJson)));
      expect(u.username, 'operator');
      expect(u.role, UserRole.operator);
      expect(u.role.canOperate, isTrue);
      expect(UserRole.parse('viewer').canOperate, isFalse);
      expect(UserRole.parse('admin').canOperate, isTrue);
      expect(UserRole.parse('superuser'), UserRole.unknown);
    });

    test('Robot with nested last_event, path and enabled', () {
      final r = Robot.fromJson(JsonReader(Map.of(robotJson)));
      expect(r.id, 'fl1');
      expect(r.mode, RobotMode.busy);
      expect(r.safetyState, SafetyState.normal);
      expect(r.batteryPct, 82.5);
      expect(r.yaw, closeTo(1.57, 1e-9));
      expect(r.carryingPalletId, 7);
      expect(r.currentTaskId, 'T-0042');
      expect(r.route, ['N3', 'N4', 'N7']);
      expect(r.path, [(1.2, 0.45), (1.2, 1.0)]);
      expect(r.lastEvent?.code, 'person_detected');
      expect(r.lastSeen, DateTime.utc(2026, 10, 16, 19, 50));
      expect(r.enabled, isTrue);
      expect(r.effectiveMode, RobotMode.busy);
    });

    test('disabled spare robot and absent `enabled`', () {
      final spare = Robot.fromJson(JsonReader(Map.of(spareRobotJson)));
      expect(spare.enabled, isFalse);
      expect(spare.effectiveMode, RobotMode.offline);
      expect(spare.lastEvent, isNull);
      final legacy = Map<String, dynamic>.of(robotJson)..remove('enabled');
      expect(Robot.fromJson(JsonReader(legacy)).enabled, isTrue);
    });

    test('unknown enum values never throw', () {
      final r = Robot.fromJson(
        JsonReader({
          ...robotJson,
          'mode': 'teleporting',
          'safety_state': 'weird',
          'battery_pct': 140,
        }),
      );
      expect(r.mode, RobotMode.unknown);
      expect(r.safetyState, SafetyState.unknown);
      expect(r.batteryPct, 100, reason: 'clamped to 0..100');
    });

    test('Task', () {
      final t = WarehouseTask.fromJson(JsonReader(Map.of(taskJson)));
      expect(t.status, TaskStatus.toPickup);
      expect(t.canCancel, isTrue);
      expect(t.fromCode, 'R1-L2');
      expect(t.toLocationId, 12);
      expect(t.finishedAt, isNull);
      expect(t.createdBy, 'operator');
      final done = WarehouseTask.fromJson(
        JsonReader({...taskJson, 'status': 'done'}),
      );
      expect(done.canCancel, isFalse);
    });

    test('Location, Pallet, InventoryMove, Event, FleetState, Reservation', () {
      final l = Location.fromJson(JsonReader(Map.of(locationJson)));
      expect(l.type, LocationType.rack);
      expect(l.occupied, isTrue);
      final p = Pallet.fromJson(JsonReader(Map.of(palletJson)));
      expect(p.status, PalletStatus.stored);
      expect(p.isMovable, isTrue);
      expect(p.weightG, 180.0, reason: 'int on the wire, double in the model');
      final m = InventoryMove.fromJson(JsonReader(Map.of(moveJson)));
      expect(m.taskId, 'T-0042');
      final e = FleetEvent.fromJson(JsonReader(Map.of(eventJson)));
      expect(e.severity, EventSeverity.critical);
      expect(e.isCritical, isTrue);
      final info = FleetEvent.fromJson(
        JsonReader({
          ...eventJson,
          'severity': 'info',
          'code': 'task_done',
          'type': 'info',
        }),
      );
      expect(info.isCritical, isFalse);
      final watchdog = FleetEvent.fromJson(
        JsonReader({
          ...eventJson,
          'severity': 'warning',
          'code': 'watchdog_timeout',
        }),
      );
      expect(watchdog.isCritical, isTrue, reason: 'alarm code list');
      final f = FleetState.fromJson(JsonReader(Map.of(fleetJson)));
      expect(f.estop, isFalse);
      expect(f.robotsTotal, 4);
      final res = Reservation.fromJson(JsonReader(Map.of(reservationJson)));
      expect(res.segmentId, 'A11--R1-W1');
    });

    test('Login grant', () {
      final g = LoginGrant.fromJson(
        JsonReader({
          'access_token': 'abc',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': userJson,
        }),
      );
      expect(g.accessToken, 'abc');
      expect(g.expiresIn, 3600);
      expect(g.user.role, UserRole.operator);
    });

    test('Map with double-dash segment ids', () {
      final m = WarehouseMap.fromJson(JsonReader(Map.of(mapJson)));
      expect(m.widthM, 4.0);
      expect(m.nodes, hasLength(2));
      expect(m.edges.single.id, 'A11--R1-W1');
      expect(m.zones.single.kind, ZoneKind.pedestrian);
      expect(m.zones.single.polygon, hasLength(4));
      expect(m.locations.single.code, 'R1-L2');
      // Fallback id when the server omits it: sorted, double dash.
      final e = MapEdge.fromJson(JsonReader({'a': 'R1-W1', 'b': 'A11'}));
      expect(e.id, 'A11--R1-W1');
      expect(MapEdge.splitSegmentId('A11--R1-W1'), ('A11', 'R1-W1'));
      expect(MapEdge.splitSegmentId('bad'), isNull);
    });

    test('Map rejects a missing size', () {
      expect(
        () => WarehouseMap.fromJson(JsonReader({'nodes': []})),
        throwsA(isA<JsonContractException>()),
      );
    });
  });

  group('WS frames', () {
    test('snapshot', () {
      final f = LiveFrame.parse(snapshotFrame());
      expect(f, isA<SnapshotFrame>());
      final s = f as SnapshotFrame;
      expect(s.robots.map((r) => r.id), ['fl1', 'fl4']);
      expect(s.reservations.single.segmentId, 'A11--R1-W1');
      expect(s.fleet?.robotsOnline, 3);
    });

    test('task, event, inventory, pong', () {
      expect(
        (LiveFrame.parse({'type': 'task', 'data': taskJson}) as TaskFrame)
            .task
            .id,
        'T-0042',
      );
      expect(
        (LiveFrame.parse({'type': 'event', 'data': eventJson}) as EventFrame)
            .event
            .code,
        'person_detected',
      );
      final inv =
          LiveFrame.parse({
                'type': 'inventory',
                'data': {'pallet': palletJson, 'move': moveJson},
              })
              as InventoryFrame;
      expect(inv.pallet?.sku, 'SKU-0007');
      expect(inv.move?.toCode, 'DOCK-OUT-1');
      expect(LiveFrame.parse('{"type":"pong"}'), isA<PongFrame>());
    });

    test('garbage is an UnknownFrame, never an exception', () {
      expect(LiveFrame.parse('not json'), isA<UnknownFrame>());
      expect(LiveFrame.parse('[1,2]'), isA<UnknownFrame>());
      expect(
        LiveFrame.parse({'type': 'task', 'data': <String, dynamic>{}}),
        isA<UnknownFrame>(),
      );
      expect(LiveFrame.parse({'type': 'future_thing'}), isA<UnknownFrame>());
    });
  });
}
