import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/result.dart';
import 'models/robot.dart';

/// `/api/fleet/*` and `/api/robots/*`.
class FleetRepository {
  FleetRepository(this._dio);

  final Dio _dio;

  /// `GET /api/fleet/state`.
  Future<Result<FleetState>> state() => guardApi(
    () => callApi(
      'GET /api/fleet/state',
      () => _dio.get<dynamic>('/api/fleet/state'),
      (res) => FleetState.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'GET /api/fleet/state'),
      ),
    ),
  );

  /// `POST /api/fleet/estop` — Stop all / release (SF-11, operator).
  Future<Result<FleetState>> estop({required bool engaged}) => guardApi(
    () => callApi(
      'POST /api/fleet/estop',
      () => _dio.post<dynamic>(
        '/api/fleet/estop',
        data: {'engaged': engaged},
        // A stop must not sit in a slow queue: fail fast and let the person
        // press again.
        options: Options(
          sendTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ),
      (res) => FleetState.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'POST /api/fleet/estop'),
      ),
    ),
  );

  /// `GET /api/robots`.
  Future<Result<List<Robot>>> robots() => guardApi(
    () => callApi(
      'GET /api/robots',
      () => _dio.get<dynamic>('/api/robots'),
      (res) => ApiEnvelope.unwrapList(
        res.data,
        Robot.fromJson,
        endpoint: 'GET /api/robots',
      ),
    ),
  );

  /// `POST /api/robots/{id}/cmd`.
  Future<Result<Robot>> command(String id, RobotCommand cmd) => guardApi(
    () => callApi(
      'POST /api/robots/{id}/cmd',
      () => _dio.post<dynamic>(
        '/api/robots/${Uri.encodeComponent(id)}/cmd',
        data: {'cmd': cmd.wire},
      ),
      (res) => Robot.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'POST /api/robots/{id}/cmd'),
      ),
    ),
  );

  /// `POST /api/robots/{id}/mode` — manual / auto (FR-10).
  Future<Result<Robot>> setMode(String id, {required bool manual}) => guardApi(
    () => callApi(
      'POST /api/robots/{id}/mode',
      () => _dio.post<dynamic>(
        '/api/robots/${Uri.encodeComponent(id)}/mode',
        data: {'mode': manual ? 'manual' : 'auto'},
      ),
      (res) => Robot.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'POST /api/robots/{id}/mode'),
      ),
    ),
  );

  /// `POST /api/robots/{id}/teleop` — one manual-drive command (UI-08).
  /// Short timeouts: a late teleop command is worse than a dropped one.
  Future<Result<TeleopAck>> teleop(
    String id, {
    required double v,
    required double w,
    required int lift,
  }) => guardApi(
    () => callApi(
      'POST /api/robots/{id}/teleop',
      () => _dio.post<dynamic>(
        '/api/robots/${Uri.encodeComponent(id)}/teleop',
        data: {'v': v, 'w': w, 'lift': lift},
        options: Options(
          sendTimeout: const Duration(milliseconds: 400),
          receiveTimeout: const Duration(milliseconds: 600),
        ),
      ),
      (res) => TeleopAck.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'POST /api/robots/{id}/teleop'),
      ),
    ),
  );
}
