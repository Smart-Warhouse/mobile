import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sw_floor/app.dart';
import 'package:sw_floor/core/providers.dart';
import 'package:sw_floor/core/storage/app_storage.dart';
import 'package:sw_floor/features/alerts/presentation/providers/alerts_controller.dart';
import 'package:sw_floor/features/auth/presentation/login_screen.dart';
import 'package:sw_floor/features/fleet/presentation/fleet_screen.dart';

import '../support/contract_fixtures.dart';
import '../support/fakes.dart';

class _SilentAlarm extends Alarm {
  int rings = 0;

  @override
  Future<void> ring() async => rings++;
}

class _Harness {
  _Harness(this.adapter, this.channel, this.alarm);

  final FakeAdapter adapter;
  final FakeWebSocketChannel channel;
  final _SilentAlarm alarm;
}

Future<_Harness> _pumpSignedIn(
  WidgetTester tester, {
  String locale = 'ar',
  Map<String, dynamic> user = userJson,
}) async {
  SharedPreferences.setMockInitialValues({
    'sw.server_url': 'http://wh.test:8000',
    'sw.user': jsonEncode(user),
    'sw.locale': locale,
  });
  final prefs = await SharedPreferences.getInstance();
  final secrets = MemorySecretStore()..values[AppPrefs.tokenKey] = 'jwt';
  final adapter = FakeAdapter({
    'GET /api/auth/me': FakeReply.ok(user),
    'GET /api/events': FakeReply.ok(
      [],
      meta: {'total': 0, 'limit': 100, 'offset': 0},
    ),
    'GET /api/tasks': FakeReply.ok(
      [taskJson],
      meta: {'total': 1, 'limit': 50, 'offset': 0},
    ),
    'GET /api/map': FakeReply.ok(mapJson),
    'GET /api/pallets': FakeReply.ok([palletJson]),
    'GET /api/pallets/7/moves': FakeReply.ok([moveJson]),
    'GET /api/locations': FakeReply.ok([
      locationJson,
      {
        ...locationJson,
        'id': 12,
        'code': 'DOCK-OUT-1',
        'type': 'dock_out',
        'occupied': false,
        'pallet_id': null,
      },
    ]),
    'POST /api/robots/fl1/mode': FakeReply.ok({...robotJson, 'mode': 'manual'}),
    'POST /api/robots/fl1/teleop': FakeReply.ok({
      'accepted': true,
      'limited_v': 0.1,
    }),
    'POST /api/fleet/estop': FakeReply.ok({
      ...fleetJson,
      'estop': true,
      'estop_by': 'operator',
      'estop_at': '2026-10-16T19:51:00Z',
    }),
  });
  final channel = FakeWebSocketChannel();
  final alarm = _SilentAlarm();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secretStoreProvider.overrideWithValue(secrets),
        httpAdapterProvider.overrideWithValue(adapter),
        channelFactoryProvider.overrideWithValue((_) => channel),
        alarmProvider.overrideWithValue(alarm),
      ],
      child: const SwFloorApp(),
    ),
  );
  await _settle(tester);
  channel.serverSend(snapshotFrame());
  await _settle(tester);
  return _Harness(adapter, channel, alarm);
}

/// Spinners never settle, so pump a fixed 2 s instead of pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Disposes the ProviderScope so the socket's timers are cancelled.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  testWidgets('Arabic (default) renders RTL with STOP ALL and the fleet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpSignedIn(tester);

    expect(find.byType(FleetScreen), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(FleetScreen))),
      TextDirection.rtl,
    );
    expect(find.text('إيقاف الكل'), findsOneWidget);
    expect(find.text('Forklift 1'), findsOneWidget);
    expect(find.text('مشغولة'), findsOneWidget);
    expect(find.text('معطّلة (احتياطية)'), findsOneWidget, reason: 'fl4');
    expect(find.text('مباشر'), findsOneWidget, reason: 'live chip');
    expect(tester.takeException(), isNull);

    await _teardown(tester);
  });

  testWidgets('hold STOP ALL → POST estop → full-screen red state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final h = await _pumpSignedIn(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('stop-all-button'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await g.up();
    await _settle(tester);

    final estop = h.adapter.requests.where(
      (r) => r.method == 'POST' && r.path == '/api/fleet/estop',
    );
    expect(estop, hasLength(1));
    expect(estop.single.body, {'engaged': true});
    expect(find.byKey(const ValueKey('estop-overlay')), findsOneWidget);
    expect(find.text('الأسطول متوقف'), findsOneWidget);
    expect(find.text('تحرير الإيقاف'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('critical WS event raises the banner and the alarm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final h = await _pumpSignedIn(tester);
    h.channel.serverSend({'type': 'event', 'data': eventJson});
    await _settle(tester);
    expect(find.byKey(const ValueKey('alert-banner')), findsOneWidget);
    expect(find.text('شخص قريب من المسار'), findsWidgets);
    expect(h.alarm.rings, 1);

    await _teardown(tester);
  });

  testWidgets('WS close 4401 signs out to login', (tester) async {
    final h = await _pumpSignedIn(tester);
    await h.channel.serverClose(4401);
    await _settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('انتهت الجلسة، سجّل الدخول مجدداً'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('English is LTR; viewer sees read-only cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpSignedIn(tester, locale: 'en', user: viewerJson);
    expect(
      Directionality.of(tester.element(find.byType(FleetScreen))),
      TextDirection.ltr,
    );
    expect(find.text('STOP ALL'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Viewer account: read only'), findsWidgets);
    await _teardown(tester);
  });

  testWidgets('every tab and the drive / move screens lay out in RTL at '
      '360 dp', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final h = await _pumpSignedIn(tester);
    for (final tab in [
      'الخريطة',
      'المهام',
      'المخزون',
      'التنبيهات',
      'الأسطول',
    ]) {
      await tester.tap(find.text(tab).last);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: tab);
    }
    expect(h.adapter.requests.any((r) => r.path == '/api/map'), isTrue);

    // Inventory → pallet detail with history.
    await tester.tap(find.text('المخزون').last);
    await _settle(tester);
    await tester.tap(find.text('SKU-0007').first);
    await _settle(tester);
    expect(find.text('سجل الحركة'), findsOneWidget);
    expect(find.text('من R1-L2 إلى DOCK-OUT-1'), findsOneWidget);

    // Move this pallet → free destination list.
    await tester.tap(find.text('نقل هذه البالية'));
    await _settle(tester);
    expect(find.text('DOCK-OUT-1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _teardown(tester);
  });

  testWidgets('manual drive: teleop only while the dead-man is held, auto on '
      'leave', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final h = await _pumpSignedIn(tester);
    List<RecordedRequest> teleops() => h.adapter.requests
        .where((r) => r.path == '/api/robots/fl1/teleop')
        .toList();

    await tester.tap(find.byTooltip('قيادة يدوية'));
    await _settle(tester);
    await tester.tap(find.text('اختر رافعة').last);
    await _settle(tester);
    await tester.tap(find.text('Forklift 1').last);
    await _settle(tester);
    await tester.tap(find.text('التحويل إلى يدوي'));
    await _settle(tester);
    final mode = h.adapter.requests.where(
      (r) => r.path == '/api/robots/fl1/mode',
    );
    expect(mode.single.body, {'mode': 'manual'});
    expect(teleops(), isEmpty, reason: 'nothing sent before the dead-man');

    await tester.ensureVisible(find.byKey(const ValueKey('deadman')));
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('deadman'))),
    );
    await tester.pump(const Duration(milliseconds: 1000));
    final whileHeld = teleops().length;
    expect(whileHeld, inInclusiveRange(9, 12), reason: '10 Hz');
    await g.up();
    await _settle(tester);
    final afterRelease = teleops().length;
    expect(teleops().last.body, {'v': 0.0, 'w': 0.0, 'lift': 0});
    await _settle(tester);
    expect(teleops().length, afterRelease, reason: 'release → stop sending');
    expect(find.text('بعد حد الأمان 0.10 م/ث'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Leaving the screen switches the robot back to auto.
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    expect(
      h.adapter.requests
          .where((r) => r.path == '/api/robots/fl1/mode')
          .last
          .body,
      {'mode': 'auto'},
    );

    await _teardown(tester);
  });
}
