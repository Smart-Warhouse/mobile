import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../features/alerts/data/models/fleet_event.dart';
import '../../features/auth/data/models/user.dart';
import '../../features/fleet/data/models/robot.dart';
import '../../features/pallets/data/models/pallet_models.dart';
import '../../features/tasks/data/models/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../network/api_failure.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Wire enum → localized label. Unknown values never crash a screen.
extension Labels on AppLocalizations {
  String mode(RobotMode m) => switch (m) {
    RobotMode.idle => modeIdle,
    RobotMode.busy => modeBusy,
    RobotMode.charging => modeCharging,
    RobotMode.paused => modePaused,
    RobotMode.manual => modeManual,
    RobotMode.safe => modeSafe,
    RobotMode.estop => modeEstop,
    RobotMode.error => modeError,
    RobotMode.offline => modeOffline,
    RobotMode.unknown => modeUnknown,
  };

  String safety(SafetyState s) => switch (s) {
    SafetyState.normal => safetyNormal,
    SafetyState.slow => safetySlow,
    SafetyState.stop => safetyStop,
    SafetyState.safe => safetySafe,
    SafetyState.estop => safetyEstop,
    SafetyState.unknown => modeUnknown,
  };

  String taskStatus(TaskStatus s) => switch (s) {
    TaskStatus.queued => statusQueued,
    TaskStatus.assigned => statusAssigned,
    TaskStatus.toPickup => statusToPickup,
    TaskStatus.picking => statusPicking,
    TaskStatus.toDrop => statusToDrop,
    TaskStatus.dropping => statusDropping,
    TaskStatus.done => statusDone,
    TaskStatus.failed => statusFailed,
    TaskStatus.cancelled => statusCancelled,
    TaskStatus.unknown => statusUnknown,
  };

  String palletStatus(PalletStatus s) => switch (s) {
    PalletStatus.stored => palletStored,
    PalletStatus.inTransit => palletInTransit,
    PalletStatus.reserved => palletReserved,
    PalletStatus.unknown => palletUnknown,
  };

  String locationType(LocationType t) => switch (t) {
    LocationType.rack => locRack,
    LocationType.dockIn => locDockIn,
    LocationType.dockOut => locDockOut,
    LocationType.staging => locStaging,
    LocationType.charge => locCharge,
    LocationType.unknown => locUnknown,
  };

  String priority(int p) => switch (p) {
    1 => priority1,
    2 => priority2,
    3 => priority3,
    4 => priority4,
    _ => priority5,
  };

  String role(UserRole r) => switch (r) {
    UserRole.viewer => roleViewer,
    UserRole.operator => roleOperator,
    UserRole.admin => roleAdmin,
    UserRole.unknown => roleUnknown,
  };

  String severity(EventSeverity s) => switch (s) {
    EventSeverity.info => severityInfo,
    EventSeverity.warning => severityWarning,
    EventSeverity.critical => severityCritical,
    EventSeverity.unknown => severityInfo,
  };

  String eventType(EventType t) => switch (t) {
    EventType.safety => typeSafety,
    EventType.error => typeError,
    EventType.info => typeInfo,
    EventType.unknown => typeInfo,
  };

  /// Contract §5 event codes. An unmapped code shows the server message,
  /// then the raw code, so nothing is ever hidden.
  String event(FleetEvent e) =>
      eventCode(e.code) ?? e.message ?? e.code.replaceAll('_', ' ');

  String? eventCode(String code) => switch (code) {
    'person_detected' => evPersonDetected,
    'obstacle_detected' => evObstacleDetected,
    'tof_stop' => evTofStop,
    'tof_slow' => evTofSlow,
    'estop_pressed' => evEstopPressed,
    'fleet_estop' => evFleetEstop,
    'fleet_estop_released' => evFleetEstopReleased,
    'watchdog_timeout' => evWatchdogTimeout,
    'wifi_lost' => evWifiLost,
    'robot_offline' => evRobotOffline,
    'robot_online' => evRobotOnline,
    'battery_low' => evBatteryLow,
    'battery_critical' => evBatteryCritical,
    'go_charge' => evGoCharge,
    'charged' => evCharged,
    'task_assigned' => evTaskAssigned,
    'task_done' => evTaskDone,
    'task_failed' => evTaskFailed,
    'pickup_failed' => evPickupFailed,
    'nav_failed' => evNavFailed,
    'deadlock_resolved' => evDeadlockResolved,
    'manual_mode' => evManualMode,
    'auto_mode' => evAutoMode,
    'paused' => evPaused,
    'resumed' => evResumed,
    'reset' => evReset,
    _ => null,
  };

  /// Maps a failure to text. Never shows the English server `message` to
  /// Arabic users unless the code has no mapping (contract §1).
  String failure(ApiFailure f) => switch (f) {
    NetworkFailure() => errNetwork,
    ContractFailure() => errContract,
    ServerFailure(:final code, :final statusCode, :final message) =>
      switch (code) {
        ErrorCode.validationError => errValidation,
        ErrorCode.unauthorized => errUnauthorized,
        ErrorCode.invalidCredentials => errInvalidCredentials,
        ErrorCode.forbidden => errForbidden,
        ErrorCode.notFound => errNotFound,
        ErrorCode.taskNotFound => errTaskNotFound,
        ErrorCode.robotNotFound => errRobotNotFound,
        ErrorCode.palletNotFound => errPalletNotFound,
        ErrorCode.locationNotFound => errLocationNotFound,
        ErrorCode.locationOccupied => errLocationOccupied,
        ErrorCode.palletBusy => errPalletBusy,
        ErrorCode.fleetEstopped => errFleetEstopped,
        ErrorCode.invalidState => errInvalidState,
        ErrorCode.robotOffline => errRobotOffline,
        ErrorCode.duplicate => errDuplicate,
        ErrorCode.unknown => message ?? errServer('$statusCode'),
      },
  };
}

/// Number and time formatting. Telemetry uses Western digits and is shown
/// LTR (docs/05-design-system.md "Type").
abstract final class Fmt {
  static String fixed(double v, int digits) => v.toStringAsFixed(digits);

  static String clock(DateTime t) => DateFormat('HH:mm:ss').format(t.toLocal());

  static String dateTime(DateTime t) =>
      DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());

  static String ago(AppLocalizations l10n, DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.inSeconds < 5) return l10n.timeJustNow;
    if (d.inSeconds < 60) return l10n.timeSecondsAgo('${d.inSeconds}');
    if (d.inMinutes < 60) return l10n.timeMinutesAgo('${d.inMinutes}');
    return clock(t);
  }
}
