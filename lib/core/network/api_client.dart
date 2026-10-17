import 'package:dio/dio.dart';

import 'api_failure.dart';

/// Builds the one Dio used for the warehouse server.
///
/// [AuthInterceptor] adds `Authorization: Bearer <jwt>` and
/// `Accept-Language`, and reports a 401 `unauthorized` (expired or revoked
/// token) through [onUnauthorized] so the session can sign out.
Dio createApiDio({
  required String baseUrl,
  required String? Function() token,
  required String Function() language,
  required void Function() onUnauthorized,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 5),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    AuthInterceptor(
      token: token,
      language: language,
      onUnauthorized: onUnauthorized,
    ),
  );
  return dio;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.token,
    required this.language,
    required this.onUnauthorized,
  });

  final String? Function() token;
  final String Function() language;
  final void Function() onUnauthorized;

  /// Paths that never carry the bearer token (contract §1).
  static const anonymousPaths = {'/api/auth/login', '/api/health'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = language();
    final t = token();
    if (t != null && !anonymousPaths.contains(options.path)) {
      options.headers['Authorization'] = 'Bearer $t';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final res = err.response;
    if (res != null && !anonymousPaths.contains(err.requestOptions.path)) {
      final f = failureFromResponse(res.statusCode ?? 0, res.data);
      if (f is ServerFailure && f.isUnauthorized) onUnauthorized();
    }
    handler.next(err);
  }
}
