import '../../../../core/json/json_reader.dart';
import '../../../pallets/data/models/pallet_models.dart';

enum ZoneKind {
  rack('rack'),
  dockIn('dock_in'),
  dockOut('dock_out'),
  staging('staging'),
  charge('charge'),
  pedestrian('pedestrian'),
  keepout('keepout'),
  unknown('_unknown');

  const ZoneKind(this.wire);

  final String wire;

  static ZoneKind parse(String? wire) =>
      values.firstWhere((m) => m.wire == wire, orElse: () => ZoneKind.unknown);
}

class MapNode {
  const MapNode({required this.id, required this.x, required this.y});

  final String id;
  final double x;
  final double y;

  factory MapNode.fromJson(JsonReader r) =>
      MapNode(id: r.reqString('id'), x: r.reqDouble('x'), y: r.reqDouble('y'));
}

class MapEdge {
  const MapEdge({
    required this.id,
    required this.a,
    required this.b,
    this.length,
    this.bidirectional = true,
  });

  final String id;
  final String a;
  final String b;
  final double? length;
  final bool bidirectional;

  /// Segment id convention shared by `edges[].id` and
  /// `Reservation.segment_id`: `"<a>--<b>"` with the node ids sorted
  /// (double dash, because node ids may contain single dashes).
  static String segmentId(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a--$b' : '$b--$a';

  /// Splits a segment id into its node ids, or null when malformed.
  static (String, String)? splitSegmentId(String id) {
    final i = id.indexOf('--');
    if (i <= 0 || i + 2 >= id.length) return null;
    return (id.substring(0, i), id.substring(i + 2));
  }

  factory MapEdge.fromJson(JsonReader r) {
    final a = r.reqString('a');
    final b = r.reqString('b');
    return MapEdge(
      id: r.optString('id') ?? segmentId(a, b),
      a: a,
      b: b,
      length: r.optDouble('length'),
      bidirectional: r.boolean('bidirectional', orElse: true),
    );
  }
}

class MapZone {
  const MapZone({
    required this.id,
    required this.kind,
    required this.polygon,
    this.label,
  });

  final String id;
  final ZoneKind kind;
  final String? label;
  final List<(double, double)> polygon;

  factory MapZone.fromJson(JsonReader r) => MapZone(
    id: r.reqString('id'),
    kind: ZoneKind.parse(r.optString('kind')),
    label: r.optString('label'),
    polygon: r.points('polygon'),
  );
}

/// `GET /api/map` (SV-02).
class WarehouseMap {
  const WarehouseMap({
    required this.widthM,
    required this.heightM,
    this.resolutionM,
    this.nodes = const [],
    this.edges = const [],
    this.zones = const [],
    this.locations = const [],
  });

  final double widthM;
  final double heightM;
  final double? resolutionM;
  final List<MapNode> nodes;
  final List<MapEdge> edges;
  final List<MapZone> zones;
  final List<Location> locations;

  Map<String, MapNode> get nodeById => {for (final n in nodes) n.id: n};

  factory WarehouseMap.fromJson(JsonReader r) {
    final w = r.reqDouble('width_m');
    final h = r.reqDouble('height_m');
    if (w <= 0 || h <= 0) {
      throw const JsonContractException('map size must be positive');
    }
    return WarehouseMap(
      widthM: w,
      heightM: h,
      resolutionM: r.optDouble('resolution_m'),
      nodes: r.objects('nodes', MapNode.fromJson),
      edges: r.objects('edges', MapEdge.fromJson),
      zones: r.objects('zones', MapZone.fromJson),
      locations: r.objects('locations', Location.fromJson),
    );
  }
}
