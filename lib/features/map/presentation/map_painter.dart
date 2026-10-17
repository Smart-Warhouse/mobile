import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/sw_tokens.dart';
import '../../fleet/data/models/robot.dart';
import '../data/models/warehouse_map.dart';
import '../domain/map_transform.dart';

/// Simplified live map (UI-01 lite): zones, lanes, reserved segments,
/// locations and robots as oriented glyphs.
class WarehouseMapPainter extends CustomPainter {
  WarehouseMapPainter({
    required this.map,
    required this.robots,
    required this.reservedSegments,
    required this.tokens,
    this.selectedRobotId,
  });

  final WarehouseMap map;
  final List<Robot> robots;
  final Set<String> reservedSegments;
  final SwTokens tokens;
  final String? selectedRobotId;

  /// Glyph length on screen: the real 0.524 m forklift, never under 22 px.
  static double glyphLength(MapTransform tx) => math.max(0.524 * tx.scale, 22);

  Color _zoneFill(ZoneKind k) => switch (k) {
    ZoneKind.rack => tokens.border,
    ZoneKind.dockIn || ZoneKind.dockOut => tokens.infoSoft,
    ZoneKind.staging => tokens.surface,
    ZoneKind.charge => tokens.successSoft,
    ZoneKind.pedestrian => tokens.warningSoft,
    ZoneKind.keepout => tokens.dangerSoft,
    ZoneKind.unknown => tokens.surface,
  };

  Color _zoneStroke(ZoneKind k) => switch (k) {
    ZoneKind.dockIn || ZoneKind.dockOut => tokens.info,
    ZoneKind.charge => tokens.success,
    ZoneKind.pedestrian => tokens.warning,
    ZoneKind.keepout => tokens.danger,
    _ => tokens.text3,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final tx = MapTransform(
      mapWidthM: map.widthM,
      mapHeightM: map.heightM,
      canvas: size,
    );
    canvas.drawRect(tx.mapRect, Paint()..color = tokens.surface2);
    canvas.drawRect(
      tx.mapRect,
      Paint()
        ..color = tokens.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Zones.
    for (final z in map.zones) {
      if (z.polygon.length < 3) continue;
      final path = Path()
        ..addPolygon([
          for (final p in z.polygon) tx.toCanvas(p.$1, p.$2),
        ], true);
      canvas.drawPath(path, Paint()..color = _zoneFill(z.kind));
      canvas.drawPath(
        path,
        Paint()
          ..color = _zoneStroke(z.kind).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final label = z.label;
      if (label != null && tx.scale > 40) {
        final b = path.getBounds();
        _text(canvas, label, b.center, tokens.text2, 10);
      }
    }

    // Lanes and reserved segments (SF-10).
    final nodes = map.nodeById;
    final lane = Paint()
      ..color = tokens.text3.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final reserved = Paint()
      ..color = tokens.warning
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final e in map.edges) {
      final a = nodes[e.a];
      final b = nodes[e.b];
      if (a == null || b == null) continue;
      final isReserved =
          reservedSegments.contains(e.id) ||
          reservedSegments.contains(MapEdge.segmentId(e.a, e.b));
      canvas.drawLine(
        tx.toCanvas(a.x, a.y),
        tx.toCanvas(b.x, b.y),
        isReserved ? reserved : lane,
      );
    }

    // Locations: occupied = filled with the lift colour.
    final locSize = math.max(0.12 * tx.scale, 6.0);
    for (final l in map.locations) {
      final c = tx.toCanvas(l.x, l.y);
      final r = Rect.fromCenter(center: c, width: locSize, height: locSize);
      if (l.occupied) {
        canvas.drawRect(r, Paint()..color = tokens.lift);
      }
      canvas.drawRect(
        r,
        Paint()
          ..color = tokens.text2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Planned paths.
    for (final r in robots) {
      if (r.path.length < 2 || !r.online) continue;
      final p = Path();
      final first = tx.toCanvas(r.x, r.y);
      p.moveTo(first.dx, first.dy);
      for (final pt in r.path) {
        final c = tx.toCanvas(pt.$1, pt.$2);
        p.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = tokens.accent.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Robots last, on top.
    final len = glyphLength(tx);
    for (final r in robots) {
      _robot(canvas, tx, r, len);
    }
  }

  void _robot(Canvas canvas, MapTransform tx, Robot r, double len) {
    final c = tx.toCanvas(r.x, r.y);
    final active = r.enabled && r.online;
    final danger =
        r.effectiveMode == RobotMode.estop ||
        r.effectiveMode == RobotMode.error ||
        r.effectiveMode == RobotMode.safe;
    final fill = !active
        ? tokens.text3
        : danger
        ? tokens.danger
        : tokens.lift;
    final on = active && !danger ? tokens.liftOn : tokens.surface;
    final w = len * 0.55;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tx.canvasAngle(r.yaw));
    if (r.id == selectedRobotId) {
      canvas.drawCircle(
        Offset.zero,
        len * 0.8,
        Paint()
          ..color = tokens.ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    // Body with a pointed nose along +x (the heading).
    final body = Path()
      ..moveTo(len / 2, 0)
      ..lineTo(len * 0.2, -w / 2)
      ..lineTo(-len / 2, -w / 2)
      ..lineTo(-len / 2, w / 2)
      ..lineTo(len * 0.2, w / 2)
      ..close();
    canvas.drawPath(body, Paint()..color = fill);
    canvas.drawPath(
      body,
      Paint()
        ..color = tokens.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();

    _text(canvas, r.id, c, on, math.min(11, len * 0.4), bold: true);
  }

  void _text(
    Canvas canvas,
    String s,
    Offset center,
    Color color,
    double size, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(WarehouseMapPainter old) =>
      old.map != map ||
      old.robots != robots ||
      old.reservedSegments != reservedSegments ||
      old.tokens != tokens ||
      old.selectedRobotId != selectedRobotId;
}

/// Nearest robot to a tap within [radius] px, or null.
Robot? hitRobot(
  List<Robot> robots,
  MapTransform tx,
  Offset tap, {
  double radius = 28,
}) {
  Robot? best;
  var bestD = radius;
  for (final r in robots) {
    final d = (tx.toCanvas(r.x, r.y) - tap).distance;
    if (d <= bestD) {
      best = r;
      bestD = d;
    }
  }
  return best;
}
