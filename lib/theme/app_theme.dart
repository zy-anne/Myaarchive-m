import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';
import 'app_color_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: palette.textMain,
      displayColor: palette.textMain,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.bg,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: palette.primary,
        secondary: palette.accent,
        error: palette.danger,
        surface: palette.surface,
        onSurface: palette.textMain,
        onPrimary: palette.onSolid,
      ),
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: palette.textMain,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: palette.border,
      extensions: [palette],
    );
  }

  /// [colorPalette] is the user-selected accent palette (Settings → Color
  /// Palette). Defaults to Twilight Reading Room when omitted.
  static ThemeData light([AppColorPalette? colorPalette]) =>
      _build(AppPalette.light(colorPalette), Brightness.light);

  static ThemeData dark([AppColorPalette? colorPalette]) =>
      _build(AppPalette.dark(colorPalette), Brightness.dark);
}