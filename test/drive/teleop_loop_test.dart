import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sw_floor/core/realtime/live_socket.dart';
import 'package:sw_floor/features/drive/domain/teleop_loop.dart';
import 'package:sw_floor/features/fleet/data/models/robot.dart';
import 'package:sw_floor/features/fleet/presentation/providers/fleet_providers.dart';
import 'package:sw_floor/core/json/json_reader.dart';

import '../support/contract_fixtures.dart';

void main() {
  group('TeleopCommand', () {
    test('stick maps and clamps to the contract ranges', () {
      final full = TeleopCommand.fromStick(-2, -2, lift: 5);
      expect(full.v, TeleopCommand.maxV, reason: 'up = forward, clamped');
      expect(full.w, TeleopCommand.maxW, reason: 'left = CCW, clamped');
      expect(full.lift, 1);
      final back = TeleopCommand.fromStick(0.5, 1);
      expect(back.v, closeTo(-0.3, 1e-9));
      expect(back.w, closeTo(-0.5, 1e-9));
      expect(TeleopCommand.fromStick(0, 0).isStop, isTrue);
    });
  });

  group('TeleopLoop (dead-man)', () {
    testWidgets('sends at 10 Hz only while engaged, then one stop', (
      tester,
    ) async {
      final sent = <TeleopCommand>[];
      final loop = TeleopLoop(send: (c) async => sent.add(c))
        ..command = const TeleopCommand(v: 0.2, w: 0, lift: 0);

      await tester.pump(const Duration(seconds: 1));
      expect(sent, isEmpty, reason: 'nothing before the button is held');

      loop.engage();
      await tester.pump(const Duration(milliseconds: 1000));
      // First send immediately, then every 100 ms.
      expect(sent.length, inInclusiveRange(10, 11));
      expect(sent.every((c) => c.v == 0.2), isTrue);

      loop.release();
      await tester.pump();
      final afterRelease = sent.length;
      expect(sent.last, TeleopCommand.stop);
      await tester.pump(const Duration(seconds: 2));
      expect(sent.length, afterRelease, reason: 'release → stop sending');
      loop.dispose();
    });

    testWidgets('skips ticks while a request is in flight', (tester) async {
      final pending = <Completer<void>>[];
      final loop = TeleopLoop(
        send: (c) {
          final done = Completer<void>();
          pending.add(done);
          return done.future;
        },
      );
      loop.engage();
      await tester.pump(const Duration(milliseconds: 550));
      expect(pending, hasLength(1), reason: 'no queue behind a slow request');
      pending.single.complete();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pending, hasLength(2));
      loop.dispose();
      for (final c in pending) {
        if (!c.isCompleted) c.complete();
      }
    });
  });

  test('WS reconnect backoff is 1, 2, 5, then 10 s', () {
    expect(
      [for (var i = 0; i < 6; i++) LiveSocket.backoffFor(i).inSeconds],
      [1, 2, 5, 10, 10, 10],
    );
  });

  group('RobotActions by state', () {
    Robot robot(Map<String, dynamic> over) =>
        Robot.fromJson(JsonReader({...robotJson, ...over}));

    test('busy → pause/charge; paused → resume/charge/drive', () {
      final busy = RobotActions.of(robot({}), fleetEstop: false);
      expect(busy.pause, isTrue);
      expect(busy.resume, isFalse);
      final paused = RobotActions.of(
        robot({'mode': 'paused'}),
        fleetEstop: false,
      );
      expect(paused.resume, isTrue);
      expect(paused.drive, isTrue);
      expect(
        RobotActions.of(robot({'mode': 'error'}), fleetEstop: false).reset,
        isTrue,
      );
    });

    test('nothing while estopped, offline or disabled', () {
      expect(RobotActions.of(robot({}), fleetEstop: true).any, isFalse);
      expect(
        RobotActions.of(robot({'online': false}), fleetEstop: false).any,
        isFalse,
      );
      expect(
        RobotActions.of(robot({'enabled': false}), fleetEstop: false).any,
        isFalse,
      );
    });
  });
}
