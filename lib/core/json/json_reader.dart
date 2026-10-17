/// Thrown when a payload does not match the contract (missing load-bearing
/// field, wrong type). Mapped to `ContractFailure` by `callApi`.
class JsonContractException implements Exception {
  const JsonContractException(this.message);

  final String message;

  @override
  String toString() => 'JsonContractException: $message';
}

/// Typed, non-throwing-by-default reader over a decoded JSON object.
///
/// Rules (docs/02-api-contract.md §1): snake_case keys, absent keys are
/// normal, numbers may arrive as int or double, timestamps are ISO-8601 UTC.
/// `req*` throws [JsonContractException] only for load-bearing fields.
class JsonReader {
  JsonReader(this.json);

  /// Wraps any decoded value; throws when it is not an object.
  factory JsonReader.of(Object? value, {String context = 'object'}) {
    if (value is Map<String, dynamic>) return JsonReader(value);
    if (value is Map) return JsonReader(value.cast<String, dynamic>());
    throw JsonContractException('$context is not a JSON object');
  }

  final Map<String, dynamic> json;

  bool has(String key) => json[key] != null;

  String reqString(String key) {
    final v = json[key];
    if (v is String) return v;
    if (v is num) return v.toString();
    throw JsonContractException('"$key" missing or not a string');
  }

  String? optString(String key) {
    final v = json[key];
    if (v is String) return v.isEmpty ? null : v;
    if (v is num) return v.toString();
    return null;
  }

  String string(String key, {String orElse = ''}) => optString(key) ?? orElse;

  int reqInt(String key) {
    final v = optInt(key);
    if (v == null) {
      throw JsonContractException('"$key" missing or not a number');
    }
    return v;
  }

  int? optInt(String key) {
    final v = json[key];
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? optDouble(String key) {
    final v = json[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double dbl(String key, {double orElse = 0}) => optDouble(key) ?? orElse;

  double reqDouble(String key) {
    final v = optDouble(key);
    if (v == null) {
      throw JsonContractException('"$key" missing or not a number');
    }
    return v;
  }

  bool boolean(String key, {bool orElse = false}) {
    final v = json[key];
    if (v is bool) return v;
    return orElse;
  }

  DateTime? optDateTime(String key) {
    final v = json[key];
    if (v is! String || v.isEmpty) return null;
    final parsed = DateTime.tryParse(v);
    if (parsed == null) return null;
    // A zone-less timestamp is UTC by contract.
    if (!parsed.isUtc && !_hasZone(v)) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    }
    return parsed.toUtc();
  }

  static bool _hasZone(String v) =>
      v.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(v);

  JsonReader? optObject(String key) {
    final v = json[key];
    if (v is Map) return JsonReader(v.cast<String, dynamic>());
    return null;
  }

  /// Objects in a list; a non-object entry or one that fails to parse is
  /// skipped so one bad row never blanks a whole screen.
  List<T> objects<T>(String key, T Function(JsonReader r) parse) {
    final v = json[key];
    if (v is! List) return const [];
    return readList(v, parse);
  }

  static List<T> readList<T>(
    List<dynamic> raw,
    T Function(JsonReader r) parse,
  ) {
    final out = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(parse(JsonReader(item.cast<String, dynamic>())));
      } on JsonContractException {
        continue;
      }
    }
    return out;
  }

  List<String> strings(String key) {
    final v = json[key];
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (e is String) e else if (e is num) e.toString(),
    ];
  }

  /// `[[x, y], ...]` polylines and polygons (metres).
  List<(double, double)> points(String key) {
    final v = json[key];
    if (v is! List) return const [];
    final out = <(double, double)>[];
    for (final p in v) {
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        out.add(((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }
    return out;
  }
}
