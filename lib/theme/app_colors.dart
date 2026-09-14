import 'package:flutter/material.dart';

/// Raw brand swatches, sampled directly from the "Core palette" style guide.
/// Don't use these directly in widgets — go through [AppPalette] (theme
/// extension) so light/dark mode resolve to the correct semantic role.
class BrandColors {
  BrandColors._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color frostFairy = Color(0xFFC2CCF4);
  static const Color perrywinkle = Color(0xFF8598E9);
  static const Color twilight = Color(0xFF46508A);
  static const Color mysteriousDepths = Color(0xFF07072A);
  static const Color sunlight = Color(0xFFE9CC92);
  static const Color champagne = Color(0xFFEDD29B);
  static const Color doubleCream = Color(0xFFF1D8A3);
  static const Color noodles = Color(0xFFF9E3B3);

  // Danger is given directly per-mode in the style guide (not derived by mixing).
  static const Color dangerLight = Color(0xFF9C4B5A);
  static const Color dangerDark = Color(0xFFD98C96);
}
