import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/result.dart';
import 'models/fleet_event.dart';

/// `GET /api/events` (SF-13, UI-06).
class EventsRepository {
  EventsRepository(this._dio);

  final Dio _dio;

  Future<Result<Paged<FleetEvent>>> list({
    String? type,
    String? severity,
    String? robotId,
    int limit = 100,
    int offset = 0,
  }) => guardApi(
    () => callApi(
      'GET /api/events',
      () => _dio.get<dynamic>(
        '/api/events',
        queryParameters: {
          'type': ?type,
          'severity': ?severity,
          'robot_id': ?robotId,
          'limit': limit,
          'offset': offset,
        },
      ),
      (res) => ApiEnvelope.unwrapPaged(
        res.data,
        FleetEvent.fromJson,
        endpoint: 'GET /api/events',
      ),
    ),
  );
}
