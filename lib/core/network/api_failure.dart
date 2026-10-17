import 'package:dio/dio.dart';

import '../json/json_reader.dart';

/// Wire error codes from docs/02-api-contract.md §1 "Error codes".
enum ErrorCode {
  validationError('validation_error'),
  unauthorized('unauthorized'),
  invalidCredentials('invalid_credentials'),
  forbidden('forbidden'),
  notFound('not_found'),
  taskNotFound('task_not_found'),
  robotNotFound('robot_not_found'),
  palletNotFound('pallet_not_found'),
  locationNotFound('location_not_found'),
  locationOccupied('location_occupied'),
  palletBusy('pallet_busy'),
  fleetEstopped('fleet_estopped'),
  invalidState('invalid_state'),
  robotOffline('robot_offline'),
  duplicate('duplicate'),
  unknown('_unknown');

  const ErrorCode(this.wire);

  final String wire;

  static ErrorCode parse(String? wire) {
    for (final c in values) {
      if (c.wire == wire) return c;
    }
    return ErrorCode.unknown;
  }
}

/// Every way a call can fail. Widgets switch on the type and [ErrorCode],
/// never on the English `message`.
sealed class ApiFailure implements Exception {
  const ApiFailure();
}

/// No HTTP response: server unreachable, timeout, DNS, Wi-Fi.
class NetworkFailure extends ApiFailure {
  const NetworkFailure([this.detail]);

  final String? detail;

  @override
  String toString() => 'NetworkFailure($detail)';
}

/// An HTTP error with (ideally) the contract error envelope.
class ServerFailure extends ApiFailure {
  const ServerFailure({
    required this.statusCode,
    required this.code,
    this.rawCode,
    this.message,
    this.details = const {},
  });

  final int statusCode;
  final ErrorCode code;

  /// The wire code as sent (useful when [code] is [ErrorCode.unknown]).
  final String? rawCode;

  /// English message from the server; shown only when no mapping exists.
  final String? message;
  final Map<String, dynamic> details;

  bool get isUnauthorized =>
      statusCode == 401 && code != ErrorCode.invalidCredentials;

  @override
  String toString() => 'ServerFailure($statusCode, ${rawCode ?? code.wire})';
}

/// The response arrived but did not match the contract.
class ContractFailure extends ApiFailure {
  const ContractFailure(this.endpoint, this.detail);

  final String endpoint;
  final String detail;

  @override
  String toString() => 'ContractFailure($endpoint: $detail)';
}

/// Maps a Dio error to an [ApiFailure] using the error envelope
/// `{ "error": { "code", "message", "details" } }`.
ApiFailure failureFromDio(DioException e) {
  final res = e.response;
  if (res == null) {
    return NetworkFailure(e.type.name);
  }
  return failureFromResponse(res.statusCode ?? 0, res.data);
}

ApiFailure failureFromResponse(int status, Object? body) {
  final err = body is Map ? body['error'] : null;
  if (err is Map) {
    final r = JsonReader(err.cast<String, dynamic>());
    final raw = r.optString('code');
    final details = r.optObject('details')?.json ?? const <String, dynamic>{};
    return ServerFailure(
      statusCode: status,
      code: ErrorCode.parse(raw),
      rawCode: raw,
      message: r.optString('message'),
      details: details,
    );
  }
  // A proxy or crash page: no envelope. Infer what we safely can.
  return ServerFailure(
    statusCode: status,
    code: switch (status) {
      401 => ErrorCode.unauthorized,
      403 => ErrorCode.forbidden,
      404 => ErrorCode.notFound,
      _ => ErrorCode.unknown,
    },
  );
}
