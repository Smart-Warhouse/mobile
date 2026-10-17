import 'package:dio/dio.dart';

import '../json/json_reader.dart';
import 'api_failure.dart';

/// Outcome of a repository call. Repositories never throw across their
/// boundary; they return a [Result].
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) ok,
    required R Function(ApiFailure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  ApiFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Unwraps or throws the [ApiFailure] (for FutureProviders).
  T unwrap() => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => throw failure,
  };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final ApiFailure failure;
}

/// Runs one HTTP call and parses it. [label] is `'METHOD /path/{id}'`; it
/// names a [ContractFailure]. Throws [ApiFailure] only.
Future<T> callApi<T>(
  String label,
  Future<Response<dynamic>> Function() request,
  T Function(Response<dynamic> res) parse,
) async {
  final Response<dynamic> res;
  try {
    res = await request();
  } on DioException catch (e) {
    throw failureFromDio(e);
  }
  try {
    return parse(res);
  } on ApiFailure {
    rethrow;
  } on JsonContractException catch (e) {
    throw ContractFailure(label, e.message);
  } on TypeError catch (e) {
    throw ContractFailure(label, e.toString());
  }
}

/// Converts a throwing [callApi] chain into a [Result].
Future<Result<T>> guardApi<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on ApiFailure catch (f) {
    return Err(f);
  }
}
