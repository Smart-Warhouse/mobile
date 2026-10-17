import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw_floor/core/json/json_reader.dart';
import 'package:sw_floor/core/l10n/labels.dart';
import 'package:sw_floor/core/network/api_client.dart';
import 'package:sw_floor/core/network/api_envelope.dart';
import 'package:sw_floor/core/network/api_failure.dart';
import 'package:sw_floor/core/network/result.dart';
import 'package:sw_floor/core/network/server_url.dart';
import 'package:sw_floor/features/fleet/data/fleet_repository.dart';
import 'package:sw_floor/features/tasks/data/tasks_repository.dart';
import 'package:sw_floor/l10n/generated/app_localizations_ar.dart';
import 'package:sw_floor/l10n/generated/app_localizations_en.dart';

import '../support/contract_fixtures.dart';
import '../support/fakes.dart';

Dio _dio(FakeAdapter a, {void Function()? onUnauthorized, String? token}) =>
    createApiDio(
      baseUrl: 'http://wh.test:8000',
      adapter: a,
      token: () => token,
      language: () => 'ar',
      onUnauthorized: onUnauthorized ?? () {},
    );

void main() {
  group('ApiEnvelope', () {
    test('unwrap object / list / paged', () {
      expect(
        ApiEnvelope.unwrap({
          'data': {'a': 1},
          'meta': {},
        }, endpoint: 'X').optInt('a'),
        1,
      );
      final list = ApiEnvelope.unwrapList(
        {
          'data': [
            {'id': 1},
            'junk',
            {'id': 2},
          ],
        },
        (r) => r.reqInt('id'),
        endpoint: 'X',
      );
      expect(list, [1, 2], reason: 'non-object rows are skipped');
      final paged = ApiEnvelope.unwrapPaged(
        {
          'data': [
            {'id': 1},
          ],
          'meta': {'total': 120, 'limit': 50, 'offset': 0},
        },
        (r) => r.reqInt('id'),
        endpoint: 'X',
      );
      expect(paged.total, 120);
      expect(paged.hasMore, isTrue);
    });

    test('missing envelope is a contract error', () {
      expect(
        () => ApiEnvelope.unwrap({'id': 1}, endpoint: 'X'),
        throwsA(isA<JsonContractException>()),
      );
      expect(
        () => ApiEnvelope.unwrapList({'data': {}}, (r) => r, endpoint: 'X'),
        throwsA(isA<JsonContractException>()),
      );
    });
  });

  group('error envelope mapping', () {
    test('known codes map to ErrorCode', () {
      final f = failureFromResponse(409, {
        'error': {
          'code': 'location_occupied',
          'message': 'Destination already holds a pallet',
          'details': {'location_id': 12},
        },
      });
      expect(f, isA<ServerFailure>());
      final s = f as ServerFailure;
      expect(s.code, ErrorCode.locationOccupied);
      expect(s.details['location_id'], 12);
      expect(s.message, isNotNull);
    });

    test('unknown code keeps the raw code; no envelope infers by status', () {
      final f =
          failureFromResponse(418, {
                'error': {'code': 'teapot', 'message': 'I am a teapot'},
              })
              as ServerFailure;
      expect(f.code, ErrorCode.unknown);
      expect(f.rawCode, 'teapot');
      expect(
        (failureFromResponse(403, '<html>') as ServerFailure).code,
        ErrorCode.forbidden,
      );
    });

    test('401 invalid_credentials is not a session expiry', () {
      final bad =
          failureFromResponse(401, {
                'error': {'code': 'invalid_credentials', 'message': ''},
              })
              as ServerFailure;
      expect(bad.isUnauthorized, isFalse);
      final expired =
          failureFromResponse(401, {
                'error': {'code': 'unauthorized', 'message': ''},
              })
              as ServerFailure;
      expect(expired.isUnauthorized, isTrue);
    });

    test('localized messages never leak the English message for mapped '
        'codes', () {
      final ar = AppLocalizationsAr();
      final en = AppLocalizationsEn();
      const f = ServerFailure(
        statusCode: 409,
        code: ErrorCode.fleetEstopped,
        message: 'Command refused while the fleet E-stop is engaged',
      );
      expect(ar.failure(f), ar.errFleetEstopped);
      expect(en.failure(f), en.errFleetEstopped);
      expect(ar.failure(const NetworkFailure()), ar.errNetwork);
      expect(
        ar.failure(
          const ServerFailure(
            statusCode: 500,
            code: ErrorCode.unknown,
            message: 'boom',
          ),
        ),
        'boom',
        reason: 'unmapped: fall back to the server message',
      );
      for (final c in ErrorCode.values) {
        expect(en.failure(ServerFailure(statusCode: 400, code: c)), isNotEmpty);
      }
    });
  });

  group('callApi through Dio', () {
    test('success with bearer token and snake_case body', () async {
      final a = FakeAdapter({
        'POST /api/fleet/estop': FakeReply.ok({...fleetJson, 'estop': true}),
      });
      final repo = FleetRepository(_dio(a, token: 'jwt-1'));
      final res = await repo.estop(engaged: true);
      expect(res, isA<Ok<Object>>());
      expect(res.valueOrNull!.estop, isTrue);
      final req = a.requests.single;
      expect(req.headers['Authorization'], 'Bearer jwt-1');
      expect(req.headers['Accept-Language'], 'ar');
      expect(req.body, {'engaged': true});
    });

    test('409 becomes Err(ServerFailure) with the mapped code', () async {
      final a = FakeAdapter({
        'POST /api/tasks': FakeReply.error(409, 'pallet_busy'),
      });
      final res = await TasksRepository(
        _dio(a),
      ).create(palletId: 7, toLocationId: 12, priority: 9);
      final f = res.failureOrNull as ServerFailure;
      expect(f.code, ErrorCode.palletBusy);
      expect(a.requests.single.body, {
        'pallet_id': 7,
        'to_location_id': 12,
        'priority': 5,
      }, reason: 'priority clamped to 1..5');
    });

    test('401 unauthorized triggers sign-out hook', () async {
      var signedOut = 0;
      final a = FakeAdapter({
        'GET /api/robots': FakeReply.error(401, 'unauthorized'),
      });
      final res = await FleetRepository(
        _dio(a, onUnauthorized: () => signedOut++),
      ).robots();
      expect(res.failureOrNull, isA<ServerFailure>());
      expect(signedOut, 1);
    });

    test(
      'network error → NetworkFailure; bad shape → ContractFailure',
      () async {
        final a = FakeAdapter()..offline = true;
        final r1 = await FleetRepository(_dio(a)).robots();
        expect(r1.failureOrNull, isA<NetworkFailure>());

        final b = FakeAdapter({
          'GET /api/robots': const FakeReply(200, {'robots': []}),
        });
        final r2 = await FleetRepository(_dio(b)).robots();
        expect(r2.failureOrNull, isA<ContractFailure>());
      },
    );
  });

  group('server URL', () {
    test('normalises what people type', () {
      expect(
        normalizeServerUrl('192.168.50.2:8000'),
        'http://192.168.50.2:8000',
      );
      expect(
        normalizeServerUrl(' http://10.0.2.2:8000/api/ '),
        'http://10.0.2.2:8000',
      );
      expect(normalizeServerUrl(''), isNull);
      expect(normalizeServerUrl('ftp://x'), isNull);
    });

    test('ws url carries the token', () {
      final u = liveSocketUri('http://192.168.50.2:8000', 'a.b.c');
      expect(u.toString(), 'ws://192.168.50.2:8000/ws/live?token=a.b.c');
      expect(liveSocketUri('https://wh.example', 't').scheme, 'wss');
    });
  });
}
