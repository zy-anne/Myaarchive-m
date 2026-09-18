import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_color_palette.dart';

/// Semantic color roles for the app, resolved per-mode from the style guide.
///
/// Light mode:
///   bg = white + 3% Frost Fairy · surface = white + 10% Frost Fairy
///   border = 55% Frost Fairy · text = Mysterious Depths · primary = selected palette
///   accent = selected palette accent · danger = #9C4B5A
///
/// Dark mode ("lamplight"):
///   bg = Mysterious Depths · surface = 82% Depths / 18% Twilight
///   border = 62% Twilight / 38% Depths · text = white + 8% Frost Fairy
///   primary = selected palette's dark-mode tone (the "role-swap") · accent = selected palette accent (constant)
///   danger = #D98C96 · onSolid = ink navy (since primary is now light)
///
/// The primary/accent roles come from an [AppColorPalette] chosen in
/// Settings → Color Palette; everything else follows the fixed Twilight
/// Reading Room base regardless of which accent palette is active.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color surface;
  final Color border;
  final Color textMain;
  final Color textSecondary;
  final Color primary;
  final Color accent;
  final Color danger;
  final Color onSolid;
  final Color star;
  final Color starEmpty;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.border,
    required this.textMain,
    required this.textSecondary,
    required this.primary,
    required this.accent,
    required this.danger,
    required this.onSolid,
    required this.star,
    required this.starEmpty,
  });

  factory AppPalette.light([AppColorPalette? colorPalette]) {
    final p = colorPalette ?? AppColorPalettes.twilightReadingRoom;
    const textMain = BrandColors.mysteriousDepths;
    return AppPalette(
      bg: const Color(0xFFFDFDFF), // white + 3% Frost Fairy
      surface: const Color(0xFFF9FAFE), // white + 10% Frost Fairy
      border: const Color(0xFFDDE3F9), // 55% Frost Fairy
      textMain: textMain,
      textSecondary: textMain.withValues(alpha: 0.62),
      primary: p.primaryLight,
      accent: p.accent,
      danger: BrandColors.dangerLight,
      onSolid: BrandColors.white,
      star: BrandColors.champagne,
      starEmpty: const Color(0xFFDDE3F9),
    );
  }

  factory AppPalette.dark([AppColorPalette? colorPalette]) {
    final p = colorPalette ?? AppColorPalettes.twilightReadingRoom;
    const textMain = Color(0xFFFAFBFE); // white + 8% Frost Fairy
    return AppPalette(
      bg: BrandColors.mysteriousDepths,
      surface: const Color(0xFF12143B), // 82% Depths / 18% Twilight
      border: const Color(0xFF2E3466), // 62% Twilight / 38% Depths
      textMain: textMain,
      textSecondary: textMain.withValues(alpha: 0.6),
      primary: p.primaryDark, // deliberate role-swap
      accent: p.accent, // stays constant across modes
      danger: BrandColors.dangerDark,
      onSolid: BrandColors.mysteriousDepths, // flips to ink navy
      star: BrandColors.sunlight,
      starEmpty: const Color(0xFF2E3466),
    );
  }

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? border,
    Color? textMain,
    Color? textSecondary,
    Color? primary,
    Color? accent,
    Color? danger,
    Color? onSolid,
    Color? star,
    Color? starEmpty,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      textMain: textMain ?? this.textMain,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      onSolid: onSolid ?? this.onSolid,
      star: star ?? this.star,
      starEmpty: starEmpty ?? this.starEmpty,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onSolid: Color.lerp(onSolid, other.onSolid, t)!,
      star: Color.lerp(star, other.star, t)!,
      starEmpty: Color.lerp(starEmpty, other.starEmpty, t)!,
    );
  }
}

/// Convenience accessor: `context.palette.primary`
extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}