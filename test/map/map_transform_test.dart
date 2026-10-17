import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sw_floor/core/json/json_reader.dart';
import 'package:sw_floor/features/fleet/data/models/robot.dart';
import 'package:sw_floor/features/map/domain/map_transform.dart';
import 'package:sw_floor/features/map/presentation/map_painter.dart';

import '../support/contract_fixtures.dart';

void main() {
  group('MapTransform', () {
    // 4 m x 3 m map on a 400 x 400 canvas with 0 padding: scale 100 px/m,
    // letterboxed vertically by 50 px.
    final tx = MapTransform(
      mapWidthM: 4,
      mapHeightM: 3,
      canvas: const Size(400, 400),
      padding: 0,
    );

    test('uniform scale and centring', () {
      expect(tx.scale, 100);
      expect(tx.offsetX, 0);
      expect(tx.offsetY, 50);
      expect(tx.mapRect, const Rect.fromLTWH(0, 50, 400, 300));
    });

    test('map origin is bottom-left, +y up', () {
      expect(tx.toCanvas(0, 0), const Offset(0, 350));
      expect(tx.toCanvas(4, 3), const Offset(400, 50));
      expect(tx.toCanvas(2, 1.5), const Offset(200, 200));
    });

    test('round trip', () {
      for (final p in [(0.0, 0.0), (1.2, 0.45), (3.9, 2.7)]) {
        final back = tx.toMap(tx.toCanvas(p.$1, p.$2));
        expect(back.$1, closeTo(p.$1, 1e-9));
        expect(back.$2, closeTo(p.$2, 1e-9));
      }
    });

    test('padding shrinks the drawable area', () {
      final padded = MapTransform(
        mapWidthM: 4,
        mapHeightM: 3,
        canvas: const Size(420, 420),
        padding: 10,
      );
      expect(padded.scale, 100);
      expect(padded.toCanvas(0, 3), const Offset(10, 60));
    });

    test('yaw (CCW, +y up) becomes a clockwise canvas angle', () {
      expect(tx.canvasAngle(0), 0);
      expect(tx.canvasAngle(math.pi / 2), -math.pi / 2);
      // Heading +y on the map points up on the screen.
      final a = tx.canvasAngle(math.pi / 2);
      final dir = Offset(math.cos(a), math.sin(a));
      expect(dir.dx, closeTo(0, 1e-9));
      expect(dir.dy, closeTo(-1, 1e-9));
    });
  });

  test('tap hit-test finds the nearest robot within the radius', () {
    final tx = MapTransform(
      mapWidthM: 4,
      mapHeightM: 3,
      canvas: const Size(400, 400),
      padding: 0,
    );
    final r = Robot.fromJson(JsonReader(Map.of(robotJson))); // (1.2, 0.45)
    final at = tx.toCanvas(r.x, r.y);
    expect(hitRobot([r], tx, at + const Offset(5, 5))?.id, 'fl1');
    expect(hitRobot([r], tx, at + const Offset(60, 0)), isNull);
  });
}
