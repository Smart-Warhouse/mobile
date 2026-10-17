import '../json/json_reader.dart';

/// A page of results with the contract paging meta `{total, limit, offset}`.
class Paged<T> {
  const Paged({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;
}

/// Unwraps the success envelope `{ "data": ..., "meta": {...} }`
/// (docs/02-api-contract.md §1).
abstract final class ApiEnvelope {
  static Object? _data(Object? body, String endpoint) {
    if (body is! Map || !body.containsKey('data')) {
      throw JsonContractException('$endpoint: response has no "data" envelope');
    }
    return body['data'];
  }

  /// `data` is an object.
  static JsonReader unwrap(Object? body, {required String endpoint}) =>
      JsonReader.of(_data(body, endpoint), context: '$endpoint data');

  /// `data` is an array of objects.
  static List<T> unwrapList<T>(
    Object? body,
    T Function(JsonReader r) parse, {
    required String endpoint,
  }) {
    final data = _data(body, endpoint);
    if (data is! List) {
      throw JsonContractException('$endpoint: "data" is not an array');
    }
    return JsonReader.readList(data, parse);
  }

  /// `data` is an array and `meta` carries paging.
  static Paged<T> unwrapPaged<T>(
    Object? body,
    T Function(JsonReader r) parse, {
    required String endpoint,
  }) {
    final items = unwrapList(body, parse, endpoint: endpoint);
    final metaRaw = (body as Map)['meta'];
    final meta = metaRaw is Map
        ? JsonReader(metaRaw.cast<String, dynamic>())
        : JsonReader(const {});
    return Paged(
      items: items,
      total: meta.optInt('total') ?? items.length,
      limit: meta.optInt('limit') ?? items.length,
      offset: meta.optInt('offset') ?? 0,
    );
  }
}
