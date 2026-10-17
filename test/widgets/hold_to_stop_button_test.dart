import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw_floor/core/theme/app_theme.dart';
import 'package:sw_floor/core/widgets/hold_to_stop_button.dart';

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String? ?? '');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onFire,
    bool enabled = true,
    VoidCallback? onDisabledPress,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness: Brightness.light, languageCode: 'en'),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: HoldToStopButton(
              label: 'STOP ALL',
              hint: 'Press and hold for 1 second',
              semanticsLabel: 'Stop all',
              enabled: enabled,
              onFire: onFire,
              onDisabledPress: onDisabledPress,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a short press does not fire', (tester) async {
    var fired = 0;
    await pump(tester, onFire: () => fired++);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('stop-all-button'))),
    );
    await tester.pump(); // first frame starts the hold ticker
    await tester.pump(const Duration(milliseconds: 500));
    await g.up();
    await tester.pumpAndSettle();
    expect(fired, 0);
  });

  testWidgets('holding 1 s fires once, with heavy haptic', (tester) async {
    var fired = 0;
    await pump(tester, onFire: () => fired++);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('stop-all-button'))),
    );
    await tester.pump(); // first frame starts the hold ticker
    await tester.pump(const Duration(milliseconds: 600));
    expect(fired, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(fired, 1);
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    // Keep holding: no second shot.
    await tester.pump(const Duration(seconds: 2));
    expect(fired, 1);
    await g.up();
    await tester.pumpAndSettle();
    expect(fired, 1);
  });

  testWidgets('release then hold again restarts the timer', (tester) async {
    var fired = 0;
    await pump(tester, onFire: () => fired++);
    final center = tester.getCenter(
      find.byKey(const ValueKey('stop-all-button')),
    );
    var g = await tester.startGesture(center);
    await tester.pump(); // first frame starts the hold ticker
    await tester.pump(const Duration(milliseconds: 900));
    await g.up();
    await tester.pumpAndSettle();
    g = await tester.startGesture(center);
    await tester.pump(); // first frame starts the hold ticker
    await tester.pump(const Duration(milliseconds: 300));
    expect(fired, 0, reason: 'progress does not carry over');
    await tester.pump(const Duration(milliseconds: 800));
    expect(fired, 1);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('disabled (viewer) never fires but explains', (tester) async {
    var fired = 0;
    var explained = 0;
    await pump(
      tester,
      enabled: false,
      onFire: () => fired++,
      onDisabledPress: () => explained++,
    );
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('stop-all-button'))),
    );
    await tester.pump(); // first frame starts the hold ticker
    await tester.pump(const Duration(seconds: 2));
    await g.up();
    await tester.pumpAndSettle();
    expect(fired, 0);
    expect(explained, 1);
  });
}
