import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/result.dart';
import 'models/warehouse_map.dart';

/// `GET /api/map` (SV-02).
class MapRepository {
  MapRepository(this._dio);

  final Dio _dio;

  Future<Result<WarehouseMap>> map() => guardApi(
    () => callApi(
      'GET /api/map',
      () => _dio.get<dynamic>('/api/map'),
      (res) => WarehouseMap.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'GET /api/map'),
      ),
    ),
  );
}
