import 'package:flutter/material.dart';

/// Myaarchive color palette — Twilight Reading Room aesthetic.
class AppColors {
  AppColors._();

  // ─── Twilight Reading Room core palette ──────────────────────────────
  static const Color deepIndigo = Color(0xFF1a1a2e);
  static const Color midnightPurple = Color(0xFF16213e);
  static const Color duskBlue = Color(0xFF0f3460);
  static const Color twilightAccent = Color(0xFF533483);
  static const Color warmGold = Color(0xFFe2b05e);
  static const Color softCream = Color(0xFFf5e6cc);
  static const Color roseHighlight = Color(0xFFe94560);

  // ─── Aliases & Convenience Colors ───────────────────────────────────
  static const Color primary = Color(0xFF6C48B5); // Vibrant Twilight Purple
  static const Color primaryLight = Color(0xFF9B7EDE);
  static const Color darkBackground = Color(0xFF0C101A); // Midnight dark
  static const Color darkBg = darkBackground;
  static const Color darkSurface = Color(0xFF141926);
  static const Color darkSurfaceLight = Color(0xFF181F30);
  static const Color darkSurfaceContainer = Color(0xFF1A2134);
  static const Color darkSurfaceHigh = Color(0xFF222B42);
  static const Color darkSurfaceLighter = darkSurfaceHigh;
  static const Color darkCard = Color(0xFF141926);
  static const Color darkBorder = Color(0xFF232B40);

  // ─── Text ───────────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkText = darkTextPrimary;
  static const Color darkTextSecondary = Color(0xFF8A93A6);
  static const Color darkTextMuted = darkTextSecondary;
  static const Color darkTextTertiary = Color(0xFF636D82);

  static const Color lightBg = Color(0xFFFAF6F0);
  static const Color lightSurface = Color(0xFFF5EDE3);
  static const Color lightTextPrimary = Color(0xFF2C2420);

  static const Color gold = warmGold;
  static const Color error = roseHighlight;
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
