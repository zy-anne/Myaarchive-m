import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_color_palette.dart';

/// Semantic color roles for the app, resolved per-mode from the style guide.
///
/// Light mode's background/surface tiers are a fixed, palette-agnostic
/// cool neutral (see [AppPalette.light]'s doc comment for why) — only the
/// primary/accent roles change with the selected [AppColorPalette].
///
/// Dark mode is different: its background/surface/border tiers are
/// generated at runtime by tinting a dark neutral scale with the hue of
/// the *selected* palette's `accent` color (which stays constant across
/// light/dark). That means switching the Color Palette in Settings
/// actually changes the dark-mode background — Pink Lemonade Bliss gets a
/// warm amber-black, Sakura Blossom a dusky rose-black, Twilight Reading
/// Room its original indigo — rather than every palette sharing the same
/// fixed navy with only the accent chips differing.
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
    // Neutral, palette-agnostic base — none of the AppColorPalette entries
    // (Twilight Reading Room, Pink Lemonade, Mysterious Purple, Green
    // Strawberry Latte, Saffron Serenity, Sakura Blossom) are built around
    // a warm cream/tan, so the neutral surfaces stay a true cool-neutral
    // gray instead of tying the whole app to one hue family that only
    // matches some accent choices.
    const textMain = Color(0xFF1A1E2B);
    return AppPalette(
      bg: const Color(0xFFF7F7FA),
      surface: const Color(0xFFFFFFFF),
      surfaceLight: const Color(0xFFF0F1F6),
      surfaceHigh: const Color(0xFFE4E6EE),
      border: const Color(0xFFE1E3EC),
      textMain: textMain,
      textSecondary: textMain.withValues(alpha: 0.62),
      primary: p.primaryLight,
      accent: p.accent,
      secondary: BrandColors.twilight, // muted indigo-blue, neutral enough to pair with any accent
      danger: BrandColors.dangerLight,
      success: const Color(0xFF2ECC71),
      gold: _warmGold,
      onSolid: BrandColors.white,
      star: BrandColors.champagne,
      starEmpty: const Color(0xFFE1E3EC),
      tagPalette: _tagPaletteConstant,
    );
  }

  factory AppPalette.dark([AppColorPalette? colorPalette]) {
    final p = colorPalette ?? AppColorPalettes.twilightReadingRoom;
    const textMain = Color(0xFFFAFBFE); // white + 8% Frost Fairy

    // Tint a dark neutral scale with the *selected* palette's accent hue
    // (accent is constant across light/dark, so it's a stable identity
    // color per palette) instead of always falling back to Twilight
    // Reading Room's fixed navy. Saturation stays low enough that text
    // and borders remain readable at every step; only the hue and a
    // gentle amount of chroma change between palettes.
    final hue = HSLColor.fromColor(p.accent).hue;
    Color tint(double lightness, double saturation) {
      return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
    }

    final bg = tint(0.10, 0.32); // was the fixed deepIndigo #1a1a2e
    final surface = tint(0.135, 0.30); // was the fixed midnightPurple #16213e
    final surfaceLight = tint(0.185, 0.28); // was the fixed duskBlue #0f3460
    final surfaceHigh = tint(0.32, 0.38); // was the fixed twilightAccent #533483
    final border = tint(0.24, 0.22); // was the fixed #313471

    return AppPalette(
      bg: bg,
      surface: surface,
      surfaceLight: surfaceLight,
      surfaceHigh: surfaceHigh,
      border: border,
      textMain: textMain,
      textSecondary: textMain.withValues(alpha: 0.6),
      primary: p.primaryDark, // deliberate role-swap
      accent: p.accent, // stays constant across modes
      secondary: BrandColors.frostFairy, // soft lavender-blue against indigo
      danger: BrandColors.dangerDark,
      success: const Color(0xFF2ECC71),
      gold: _warmGold,
      onSolid: bg, // matches the tinted background, whatever hue it lands on
      star: BrandColors.sunlight,
      starEmpty: border,
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