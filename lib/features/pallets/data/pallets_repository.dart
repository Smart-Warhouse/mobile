import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/result.dart';
import 'models/pallet_models.dart';

/// Inventory: `/api/pallets`, `/api/locations`.
class PalletsRepository {
  PalletsRepository(this._dio);

  final Dio _dio;

  /// `GET /api/pallets?q=` — q matches SKU, product name or ArUco id.
  Future<Result<List<Pallet>>> search(String q) => guardApi(
    () => callApi(
      'GET /api/pallets',
      () => _dio.get<dynamic>(
        '/api/pallets',
        queryParameters: {if (q.trim().isNotEmpty) 'q': q.trim()},
      ),
      (res) => ApiEnvelope.unwrapList(
        res.data,
        Pallet.fromJson,
        endpoint: 'GET /api/pallets',
      ),
    ),
  );

  /// `GET /api/pallets/{id}/moves` (UI-04).
  Future<Result<List<InventoryMove>>> moves(int palletId) => guardApi(
    () => callApi(
      'GET /api/pallets/{id}/moves',
      () => _dio.get<dynamic>('/api/pallets/$palletId/moves'),
      (res) => ApiEnvelope.unwrapList(
        res.data,
        InventoryMove.fromJson,
        endpoint: 'GET /api/pallets/{id}/moves',
      ),
    ),
  );

  /// `GET /api/locations?type=`.
  Future<Result<List<Location>>> locations({LocationType? type}) => guardApi(
    () => callApi(
      'GET /api/locations',
      () => _dio.get<dynamic>(
        '/api/locations',
        queryParameters: {'type': ?type?.wire},
      ),
      (res) => ApiEnvelope.unwrapList(
        res.data,
        Location.fromJson,
        endpoint: 'GET /api/locations',
      ),
    ),
  );
}
