import 'dart:math' as math;
import 'dart:ui';

/// Map frame (metres, origin bottom-left, +y up, yaw CCW from +x) ↔ canvas
/// (pixels, origin top-left, +y down). Uniform scale, letterboxed and
/// centred with [padding]. The map is always drawn LTR: x grows to the
/// right whatever the UI language (docs/05-design-system.md).
class MapTransform {
  MapTransform({
    required this.mapWidthM,
    required this.mapHeightM,
    required this.canvas,
    this.padding = 8,
  }) : assert(mapWidthM > 0 && mapHeightM > 0) {
    final w = math.max(canvas.width - 2 * padding, 1.0);
    final h = math.max(canvas.height - 2 * padding, 1.0);
    scale = math.min(w / mapWidthM, h / mapHeightM);
    offsetX = (canvas.width - mapWidthM * scale) / 2;
    offsetY = (canvas.height - mapHeightM * scale) / 2;
  }

  final double mapWidthM;
  final double mapHeightM;
  final Size canvas;
  final double padding;

  /// Pixels per metre.
  late final double scale;
  late final double offsetX;
  late final double offsetY;

  Offset toCanvas(double x, double y) =>
      Offset(offsetX + x * scale, offsetY + (mapHeightM - y) * scale);

  (double, double) toMap(Offset p) =>
      ((p.dx - offsetX) / scale, mapHeightM - (p.dy - offsetY) / scale);

  /// Canvas rotation (clockwise-positive, because +y is down) for a yaw.
  double canvasAngle(double yaw) => -yaw;

  /// The map rectangle on the canvas.
  Rect get mapRect =>
      Rect.fromLTWH(offsetX, offsetY, mapWidthM * scale, mapHeightM * scale);
}
