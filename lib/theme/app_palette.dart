import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_color_palette.dart';

/// Semantic color roles for the app, resolved per-mode from the style guide.
///
/// The background/surface tiers below are drawn from the "Twilight Reading
/// Room" swatch family (documented in `AppColors` as `deepIndigo`,
/// `midnightPurple`, `duskBlue`, `twilightAccent` for dark mode, and
/// `lightBg` / `lightSurface` / `softCream` / `doubleCream` for light mode).
/// Those constants existed in the codebase but were never actually wired
/// into a theme — this is what makes the background a real color instead
/// of a barely-tinted near-black / near-white pair.
///
/// The primary/accent roles still come from an [AppColorPalette] chosen in
/// Settings → Color Palette; the bg/surface/text tiers below follow the
/// fixed Twilight Reading Room base regardless of which accent palette is
/// active — same split as before, just with real color in it now.
///
/// This extension is resolved through `Theme.of(context)`, so any widget
/// that reads it via `context.palette` rebuilds automatically whenever the
/// theme changes — unlike the static `AppColors` class, which requires the
/// widget to separately watch `themeModeProvider` / `colorPaletteIdProvider`
/// (or otherwise be told to rebuild) to pick up a live change.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color surface;
  final Color surfaceLight;
  final Color surfaceHigh;
  final Color border;
  final Color textMain;
  final Color textSecondary;
  final Color primary;
  final Color accent;
  final Color secondary;
  final Color danger;
  final Color success;
  final Color gold;
  final Color onSolid;
  final Color star;
  final Color starEmpty;
  final List<Color> tagPalette;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceLight,
    required this.surfaceHigh,
    required this.border,
    required this.textMain,
    required this.textSecondary,
    required this.primary,
    required this.accent,
    required this.secondary,
    required this.danger,
    required this.success,
    required this.gold,
    required this.onSolid,
    required this.star,
    required this.starEmpty,
    required this.tagPalette,
  });

  /// Convenience alias — reads the same as `AppColors.darkTextMuted`.
  Color get textMuted => textSecondary;

  /// Deterministic color for a tag name, drawn from this palette's
  /// [tagPalette] rather than a static list — matches
  /// `AppColors.colorForTagName` but stays theme-aware.
  Color colorForTagName(String name) {
    final key = name.trim().toLowerCase();
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
      hash = ((hash * 31) + key.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return tagPalette[hash.abs() % tagPalette.length];
  }

  // Same 14-color tag palette AppColors/data-layer use — kept as one
  // constant list shared by both light and dark factories below, since tag
  // colors aren't part of the light/dark or accent-palette design language.
  static const List<Color> _tagPaletteConstant = [
    Color(0xFF5DC8CD), // cyan
    Color(0xFF9B7EDE), // purple
    Color(0xFFE58FB1), // pink
    Color(0xFF7FC9A0), // green
    Color(0xFFB9BEC7), // gray
    Color(0xFFE8C15C), // gold
    Color(0xFF6FA8DC), // blue
    Color(0xFF4FBDB0), // teal
    Color(0xFFB0A15A), // olive
    Color(0xFFDD7A6E), // rust
    Color(0xFFE3A15C), // orange
    Color(0xFF8D9DE8), // periwinkle
    Color(0xFFC98BC9), // orchid
    Color(0xFF7FBF7F), // leaf green
  ];

  // The actual "gold" swatch from the style guide — used for ratings/star
  // accents in both modes (matches `AppColors.warmGold`, a single constant
  // that was never mode-dependent to begin with).
  static const Color _warmGold = Color(0xFFE2B05E);

  factory AppPalette.light([AppColorPalette? colorPalette]) {
    final p = colorPalette ?? AppColorPalettes.twilightReadingRoom;
    // Warm cream reading-room base — matches `AppColors.lightBg` /
    // `lightSurface` / `lightTextPrimary`, instead of the near-white
    // FDFDFF/F9FAFE pair this used to resolve to.
    const textMain = Color(0xFF2C2420); // AppColors.lightTextPrimary
    return AppPalette(
      bg: const Color(0xFFFAF6F0), // AppColors.lightBg — warm cream
      surface: const Color(0xFFFFFFFF), // clean card pop off the cream bg
      surfaceLight: const Color(0xFFF5E6CC), // AppColors.softCream
      surfaceHigh: const Color(0xFFF1D8A3), // BrandColors.doubleCream
      border: const Color(0xFFE6D9C3),
      textMain: textMain,
      textSecondary: textMain.withValues(alpha: 0.62),
      primary: p.primaryLight,
      accent: p.accent,
      secondary: BrandColors.twilight, // muted indigo-blue, reads on cream
      danger: BrandColors.dangerLight,
      success: const Color(0xFF2ECC71),
      gold: _warmGold,
      onSolid: BrandColors.white,
      star: BrandColors.champagne,
      starEmpty: const Color(0xFFE6D9C3),
      tagPalette: _tagPaletteConstant,
    );
  }

  factory AppPalette.dark([AppColorPalette? colorPalette]) {
    final p = colorPalette ?? AppColorPalettes.twilightReadingRoom;
    const textMain = Color(0xFFFAFBFE); // white + 8% Frost Fairy
    return AppPalette(
      bg: const Color(0xFF1A1A2E), // AppColors.deepIndigo
      surface: const Color(0xFF16213E), // AppColors.midnightPurple
      surfaceLight: const Color(0xFF0F3460), // AppColors.duskBlue
      surfaceHigh: const Color(0xFF533483), // AppColors.twilightAccent
      border: const Color(0xFF313471), // blend of duskBlue / twilightAccent
      textMain: textMain,
      textSecondary: textMain.withValues(alpha: 0.6),
      primary: p.primaryDark, // deliberate role-swap
      accent: p.accent, // stays constant across modes
      secondary: BrandColors.frostFairy, // soft lavender-blue against indigo
      danger: BrandColors.dangerDark,
      success: const Color(0xFF2ECC71),
      gold: _warmGold,
      onSolid: const Color(0xFF1A1A2E), // matches the new deepIndigo bg
      star: BrandColors.sunlight,
      starEmpty: const Color(0xFF313471),
      tagPalette: _tagPaletteConstant,
    );
  }

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceLight,
    Color? surfaceHigh,
    Color? border,
    Color? textMain,
    Color? textSecondary,
    Color? primary,
    Color? accent,
    Color? secondary,
    Color? danger,
    Color? success,
    Color? gold,
    Color? onSolid,
    Color? star,
    Color? starEmpty,
    List<Color>? tagPalette,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border,
      textMain: textMain ?? this.textMain,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      secondary: secondary ?? this.secondary,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      gold: gold ?? this.gold,
      onSolid: onSolid ?? this.onSolid,
      star: star ?? this.star,
      starEmpty: starEmpty ?? this.starEmpty,
      tagPalette: tagPalette ?? this.tagPalette,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      onSolid: Color.lerp(onSolid, other.onSolid, t)!,
      star: Color.lerp(star, other.star, t)!,
      starEmpty: Color.lerp(starEmpty, other.starEmpty, t)!,
      // Tag palette doesn't meaningfully "animate" between two lists of
      // different accent hues — snap instead of lerping element-by-element.
      tagPalette: t < 0.5 ? tagPalette : other.tagPalette,
    );
  }
}

/// Convenience accessor: `context.palette.primary`
extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}