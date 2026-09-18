import 'package:flutter/material.dart';
import 'app_color_palette.dart';

/// Myaarchive color palette — dynamically adapts to Light/Dark mode and
/// the user-selected accent palette (Settings → Color Palette).
class AppColors {
  AppColors._();

  static bool isDark = true;
  static AppColorPalette currentPalette = AppColorPalettes.twilightReadingRoom;

  static void setTheme({required bool isDark, required AppColorPalette palette}) {
    AppColors.isDark = isDark;
    AppColors.currentPalette = palette;
  }

  // ─── Twilight Reading Room core palette (raw swatches) ───────────────
  static const Color deepIndigo = Color(0xFF1a1a2e);
  static const Color midnightPurple = Color(0xFF16213e);
  static const Color duskBlue = Color(0xFF0f3460);
  static const Color twilightAccent = Color(0xFF533483);
  static const Color warmGold = Color(0xFFe2b05e);
  static const Color softCream = Color(0xFFf5e6cc);
  static const Color roseHighlight = Color(0xFFe94560);

  // ─── Dynamic Palette Roles ──────────────────────────────────────────
  static Color get primary =>
      isDark ? currentPalette.primaryDark : currentPalette.primaryLight;
  static Color get primaryLight => currentPalette.accent;
  static Color get accent => currentPalette.accent;
  static Color get onPrimary =>
      isDark ? const Color(0xFF0C101A) : const Color(0xFFFFFFFF);

  // ─── Surfaces & Backgrounds ─────────────────────────────────────────
  static Color get darkBackground =>
      isDark ? const Color(0xFF0C101A) : const Color(0xFFF7F8FC);
  static Color get darkBg => darkBackground;
  static Color get darkSurface =>
      isDark ? const Color(0xFF141926) : const Color(0xFFFFFFFF);
  static Color get darkSurfaceLight =>
      isDark ? const Color(0xFF181F30) : const Color(0xFFF0F3FA);
  static Color get darkSurfaceContainer =>
      isDark ? const Color(0xFF1A2134) : const Color(0xFFE8ECF6);
  static Color get darkSurfaceHigh =>
      isDark ? const Color(0xFF222B42) : const Color(0xFFE0E5F2);
  static Color get darkSurfaceLighter => darkSurfaceHigh;
  static Color get darkCard => darkSurface;
  static Color get darkBorder =>
      isDark ? const Color(0xFF232B40) : const Color(0xFFDDE3F2);

  // ─── Text ───────────────────────────────────────────────────────────
  static Color get darkTextPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF151928);
  static Color get darkText => darkTextPrimary;
  static Color get darkTextSecondary =>
      isDark ? const Color(0xFF8A93A6) : const Color(0xFF656F85);
  static Color get darkTextMuted => darkTextSecondary;
  static Color get darkTextTertiary =>
      isDark ? const Color(0xFF636D82) : const Color(0xFF8F98AA);

  static const Color lightBg = Color(0xFFFAF6F0);
  static const Color lightSurface = Color(0xFFF5EDE3);
  static const Color lightTextPrimary = Color(0xFF2C2420);

  static const Color gold = warmGold;
  static Color get error => roseHighlight;
  static const Color success = Color(0xFF2ECC71);

  // ─── Tag color palette (14 colors, matches data-layer/index.js) ─────
  static const List<Color> tagPalette = [
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

  static const Color genreDefault = Color(0xFFB2BEC3);
  static const Color warningRed = Color(0xFFE74C3C);

  /// Deterministic color for a tag name.
  static Color colorForTagName(String name) {
    final key = name.trim().toLowerCase();
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
      hash = ((hash * 31) + key.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return tagPalette[hash.abs() % tagPalette.length];
  }
}
