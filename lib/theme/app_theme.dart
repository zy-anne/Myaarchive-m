import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';

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
      dividerColor: palette.border,
      extensions: [palette],
    );
  }

  static ThemeData get light => _build(AppPalette.light(), Brightness.light);
  static ThemeData get dark => _build(AppPalette.dark(), Brightness.dark);
  static ThemeData get lightTheme => light;
  static ThemeData get darkTheme => dark;
}
