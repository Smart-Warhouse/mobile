import 'package:dio/dio.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/result.dart';
import 'models/user.dart';

class LoginGrant {
  const LoginGrant({
    required this.accessToken,
    required this.user,
    this.expiresIn,
  });

  final String accessToken;
  final User user;

  /// Seconds.
  final int? expiresIn;

  factory LoginGrant.fromJson(JsonReader r) => LoginGrant(
    accessToken: r.reqString('access_token'),
    expiresIn: r.optInt('expires_in'),
    user: User.fromJson(
      r.optObject('user') ?? (throw const JsonContractException('no user')),
    ),
  );
}

class ServerHealth {
  const ServerHealth({required this.status, this.version, this.simulator});

  final String status;
  final String? version;
  final bool? simulator;

  factory ServerHealth.fromJson(JsonReader r) => ServerHealth(
    status: r.string('status'),
    version: r.optString('version'),
    simulator: r.has('simulator') ? r.boolean('simulator') : null,
  );
}

/// `/api/auth/*` and `/api/health`.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// `POST /api/auth/login` (anonymous).
  Future<Result<LoginGrant>> login(String username, String password) =>
      guardApi(
        () => callApi(
          'POST /api/auth/login',
          () => _dio.post<dynamic>(
            '/api/auth/login',
            data: {'username': username, 'password': password},
          ),
          (res) => LoginGrant.fromJson(
            ApiEnvelope.unwrap(res.data, endpoint: 'POST /api/auth/login'),
          ),
        ),
      );

  /// `GET /api/auth/me`.
  Future<Result<User>> me() => guardApi(
    () => callApi(
      'GET /api/auth/me',
      () => _dio.get<dynamic>('/api/auth/me'),
      (res) => User.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'GET /api/auth/me'),
      ),
    ),
  );

  /// `GET /api/health` (anonymous) — the "Test connection" button.
  Future<Result<ServerHealth>> health() => guardApi(
    () => callApi(
      'GET /api/health',
      () => _dio.get<dynamic>('/api/health'),
      (res) => ServerHealth.fromJson(
        ApiEnvelope.unwrap(res.data, endpoint: 'GET /api/health'),
      ),
    ),
  );
}
