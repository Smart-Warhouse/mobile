import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A recorded HTTP request.
class RecordedRequest {
  RecordedRequest(this.method, this.path, this.query, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> headers;
  final Object? body;
}

/// A canned reply.
class FakeReply {
  const FakeReply(this.status, this.body);

  final int status;
  final Object? body;

  /// `{ "data": ..., "meta": {} }`.
  factory FakeReply.ok(Object? data, {Map<String, dynamic>? meta}) =>
      FakeReply(200, {'data': data, 'meta': meta ?? <String, dynamic>{}});

  factory FakeReply.error(int status, String code, [String message = '']) =>
      FakeReply(status, {
        'error': {'code': code, 'message': message, 'details': {}},
      });
}

/// Dio adapter answering `'METHOD /path'` keys; anything else is a 404
/// `not_found` envelope. Records every request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter([Map<String, FakeReply>? routes]) : routes = routes ?? {};

  final Map<String, FakeReply> routes;
  final List<RecordedRequest> requests = [];

  /// Throw a connection error instead of replying.
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (requestStream != null) {
      final bytes = await requestStream.fold<List<int>>(
        [],
        (a, b) => a..addAll(b),
      );
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes));
    }
    requests.add(
      RecordedRequest(
        options.method,
        options.path,
        options.queryParameters,
        options.headers,
        body,
      ),
    );
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final reply =
        routes['${options.method} ${options.path}'] ??
        FakeReply.error(404, 'not_found');
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// In-memory `/ws/live` channel. Push server frames with [serverSend];
/// close with a code via [serverClose].
class FakeWebSocketChannel implements WebSocketChannel {
  final _in = StreamController<dynamic>();
  final sent = <dynamic>[];
  int? _closeCode;

  void serverSend(Map<String, dynamic> frame) => _in.add(jsonEncode(frame));

  Future<void> serverClose(int code) async {
    _closeCode = code;
    await _in.close();
  }

  @override
  Stream<dynamic> get stream => _in.stream;

  @override
  late final WebSocketSink sink = _FakeSink(this);

  @override
  Future<void> get ready => Future.value();

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._ch);

  final FakeWebSocketChannel _ch;

  @override
  void add(dynamic data) => _ch.sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_ch._in.isClosed) await _ch._in.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
