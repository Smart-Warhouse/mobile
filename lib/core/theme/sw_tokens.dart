import 'package:flutter/material.dart';

/// Semantic colour tokens from docs/05-design-system.md (`--sw-*` on the
/// web). The ONLY place raw hex values live. Widgets read them through
/// `context.sw`.
@immutable
class SwTokens extends ThemeExtension<SwTokens> {
  const SwTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentHover,
    required this.accentOn,
    required this.lift,
    required this.liftOn,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.successSoft,
    required this.warningSoft,
    required this.dangerSoft,
    required this.infoSoft,
    required this.statusOn,
    required this.stopFill,
    required this.stopOn,
    required this.ring,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color accentHover;
  final Color accentOn;
  final Color lift;
  final Color liftOn;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;
  final Color infoSoft;

  /// Foreground on a solid status fill (success/warning/danger/info).
  final Color statusOn;

  /// «إيقاف الكل» fill: danger-600 in both themes so the button reads the
  /// same everywhere (UI-07), and its foreground.
  final Color stopFill;
  final Color stopOn;
  final Color ring;

  static const light = SwTokens(
    bg: Color(0xFFF4F7F9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF2F5),
    border: Color(0xFFDCE3E8),
    text: Color(0xFF0C161E),
    text2: Color(0xFF4A6070),
    text3: Color(0xFF6E8494),
    accent: Color(0xFF0F4C5C),
    accentHover: Color(0xFF146577),
    accentOn: Color(0xFFFFFFFF),
    lift: Color(0xFFF5B400),
    liftOn: Color(0xFF3A2700),
    success: Color(0xFF16A34A),
    warning: Color(0xFFEA580C),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    successSoft: Color(0xFFECFDF3),
    warningSoft: Color(0xFFFFF7ED),
    dangerSoft: Color(0xFFFEF2F2),
    infoSoft: Color(0xFFEFF6FF),
    statusOn: Color(0xFFFFFFFF),
    stopFill: Color(0xFFDC2626),
    stopOn: Color(0xFFFFFFFF),
    ring: Color(0xFF2E9CB0),
  );

  static const dark = SwTokens(
    bg: Color(0xFF0C161E),
    surface: Color(0xFF13202A),
    surface2: Color(0xFF1A2A36),
    border: Color(0xFF26394A),
    text: Color(0xFFE9EFF3),
    text2: Color(0xFFA3B4C1),
    text3: Color(0xFF6E8494),
    accent: Color(0xFF5DBACB),
    accentHover: Color(0xFF94D3DD),
    accentOn: Color(0xFF072630),
    lift: Color(0xFFF5B400),
    liftOn: Color(0xFF3A2700),
    success: Color(0xFF22C55E),
    warning: Color(0xFFFB923C),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
    // 600 step at 15 % over `surface`, baked.
    successSoft: Color(0xFF13342F),
    warningSoft: Color(0xFF332826),
    dangerSoft: Color(0xFF312129),
    infoSoft: Color(0xFF162A47),
    statusOn: Color(0xFF0C161E),
    stopFill: Color(0xFFDC2626),
    stopOn: Color(0xFFFFFFFF),
    ring: Color(0xFF94D3DD),
  );

  @override
  SwTokens copyWith() => this;

  @override
  SwTokens lerp(ThemeExtension<SwTokens>? other, double t) {
    if (other is! SwTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SwTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      border: l(border, other.border),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      accent: l(accent, other.accent),
      accentHover: l(accentHover, other.accentHover),
      accentOn: l(accentOn, other.accentOn),
      lift: l(lift, other.lift),
      liftOn: l(liftOn, other.liftOn),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      info: l(info, other.info),
      successSoft: l(successSoft, other.successSoft),
      warningSoft: l(warningSoft, other.warningSoft),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      infoSoft: l(infoSoft, other.infoSoft),
      statusOn: l(statusOn, other.statusOn),
      stopFill: l(stopFill, other.stopFill),
      stopOn: l(stopOn, other.stopOn),
      ring: l(ring, other.ring),
    );
  }
}

/// A status colour with its soft background, for badges.
class Tone {
  const Tone(this.fg, this.soft);

  final Color fg;
  final Color soft;
}

extension SwTokensX on BuildContext {
  SwTokens get sw => Theme.of(this).extension<SwTokens>() ?? SwTokens.light;
}

/// Spacing, radii and sizes.
abstract final class Sp {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double radius = 12;
  static const double radiusSm = 8;

  /// Material minimum touch target; floor users may wear gloves, so the
  /// safety controls use [bigTapTarget].
  static const double minTapTarget = 48;
  static const double bigTapTarget = 64;
}

abstract final class SwFonts {
  static const arabic = 'ThmanyahSans';
  static const arabicDisplay = 'ThmanyahSerifText';
  static const latin = 'Lexend';
}
