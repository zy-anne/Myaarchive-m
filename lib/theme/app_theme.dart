import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';
import 'app_color_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final inter = GoogleFonts.interTextTheme(base.textTheme);
    final textTheme = inter.copyWith(
      displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: palette.textMain),
      displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: palette.textMain),
      displaySmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: palette.textMain),
      headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: palette.textMain),
      headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: palette.textMain),
      headlineSmall: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: palette.textMain),
      titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textMain),
      titleMedium: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: palette.textMain),
      titleSmall: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textMain),
      bodyLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.normal, color: palette.textMain),
      bodyMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.normal, color: palette.textMain),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: palette.textSecondary),
      labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textMain),
      labelMedium: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: palette.textSecondary),
      labelSmall: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: palette.textSecondary),
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
        onSurfaceVariant: palette.textSecondary,
        onPrimary: palette.onSolid,
        outline: palette.border,
      ),
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: palette.textMain,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: palette.textMain,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: GoogleFonts.inter(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: palette.textMain,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.normal,
          color: palette.textSecondary,
          height: 1.35,
        ),
        iconColor: palette.accent,
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
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: palette.textMain,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: palette.textSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: palette.textSecondary.withValues(alpha: 0.7),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textMain,
          side: BorderSide(color: palette.border),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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