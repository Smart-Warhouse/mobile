import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/result.dart';
import 'models/task.dart';

/// `/api/tasks` (FR-01, SV-01).
class TasksRepository {
  TasksRepository(this._dio);

  final Dio _dio;

  /// `GET /api/tasks`, newest first.
  Future<Result<Paged<WarehouseTask>>> list({
    List<TaskStatus>? statuses,
    String? robotId,
    int limit = 50,
    int offset = 0,
  }) => guardApi(
    () => callApi(
      'GET /api/tasks',
      () => _dio.get<dynamic>(
        '/api/tasks',
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.map((s) => s.wire).join(','),
          'robot_id': ?robotId,
          'limit': limit,
          'offset': offset,
        },
      ),
      (res) => ApiEnvelope.unwrapPaged(
        res.data,
        WarehouseTask.fromJson,
        endpoint: 'GET /api/tasks',
      ),
    ),
  );

  /// `POST /api/tasks` → 201 Task. Never retried automatically: a timeout
  /// may still have created the task, so the list is refreshed instead.
  Future<Result<WarehouseTask>> create({
    required int palletId,
    required int toLocationId,
    int priority = 2,
  }) => guardApi(
    () => callApi(
      'POST /api/tasks',
      () => _dio.post<dynamic>(
        '/api/tasks',
        data: {
          'pallet_id': palletId,
          'to_location_id': toLocationId,
          'priority': priority.clamp(1, 5),
        },
      ),
      (res) => WarehouseTask.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'POST /api/tasks'),
      ),
    ),
  );

  /// `POST /api/tasks/{id}/cancel`.
  Future<Result<WarehouseTask>> cancel(String id) => guardApi(
    () => callApi(
      'POST /api/tasks/{id}/cancel',
      () => _dio.post<dynamic>('/api/tasks/${Uri.encodeComponent(id)}/cancel'),
      (res) => WarehouseTask.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'POST /api/tasks/{id}/cancel'),
      ),
    ),
  );
}
