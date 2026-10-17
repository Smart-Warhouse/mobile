import 'package:flutter/material.dart';

import 'sw_tokens.dart';

/// Builds Material themes from [SwTokens]. Arabic uses Thmanyah Sans,
/// English uses Lexend with Thmanyah as fallback (docs/05-design-system.md).
abstract final class AppTheme {
  static ThemeData build({
    required Brightness brightness,
    required String languageCode,
  }) {
    final t = brightness == Brightness.dark ? SwTokens.dark : SwTokens.light;
    final family = languageCode == 'ar' ? SwFonts.arabic : SwFonts.latin;
    const fallback = [SwFonts.arabic, SwFonts.latin];

    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.accentOn,
      secondary: t.lift,
      onSecondary: t.liftOn,
      error: t.danger,
      onError: t.statusOn,
      surface: t.surface,
      onSurface: t.text,
      surfaceContainerHighest: t.surface2,
      surfaceContainer: t.surface2,
      surfaceContainerLow: t.surface,
      onSurfaceVariant: t.text2,
      outline: t.border,
      outlineVariant: t.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      fontFamily: family,
      fontFamilyFallback: fallback,
      extensions: [t],
    );

    final text = base.textTheme.apply(
      bodyColor: t.text,
      displayColor: t.text,
      fontFamily: family,
      fontFamilyFallback: fallback,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontFamily: languageCode == 'ar' ? SwFonts.arabicDisplay : family,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sp.radius),
          side: BorderSide(color: t.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.border, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.surface2,
        surfaceTintColor: Colors.transparent,
        height: 64,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.radiusSm),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.radiusSm),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.radiusSm),
          borderSide: BorderSide(color: t.ring, width: 2),
        ),
        hintStyle: TextStyle(color: t.text3),
        helperStyle: TextStyle(color: t.text2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(Sp.minTapTarget, Sp.minTapTarget),
          backgroundColor: t.accent,
          foregroundColor: t.accentOn,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sp.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(Sp.minTapTarget, Sp.minTapTarget),
          foregroundColor: t.accent,
          side: BorderSide(color: t.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sp.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(Sp.minTapTarget, Sp.minTapTarget),
          foregroundColor: t.accent,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.surface2,
        side: BorderSide(color: t.border),
        labelStyle: TextStyle(color: t.text),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.text,
        contentTextStyle: TextStyle(color: t.bg, fontFamily: family),
      ),
    );
  }
}

/// Telemetry numbers: tabular figures (pin LTR with `Directionality` or
/// `textDirection` where the value mixes digits and units).
const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
