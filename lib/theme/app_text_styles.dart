import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fonts per the style guide: Fraunces (serif — headings, wordmark),
/// Inter (UI text — applied as the base TextTheme), IBM Plex Mono
/// (labels, pills, meta text).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing ?? 0.2,
    );
  }
}
