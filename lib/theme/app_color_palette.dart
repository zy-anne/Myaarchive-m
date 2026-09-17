import 'package:flutter/material.dart';

/// A selectable accent color palette. Applies to both Light and Dark mode —
/// only the primary/accent role colors change; surfaces, borders, and base
/// text stay on the existing Twilight Reading Room foundation per mode.
class AppColorPalette {
  final String id;
  final String label;
  final List<Color> swatches; // preview dots shown in the picker
  final Color primaryLight; // primary color used in Light mode
  final Color primaryDark; // primary color used in Dark mode ("role-swap" tone)
  final Color accent; // secondary/accent color, constant across modes

  const AppColorPalette({
    required this.id,
    required this.label,
    required this.swatches,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
  });
}

class AppColorPalettes {
  AppColorPalettes._();

  static const twilightReadingRoom = AppColorPalette(
    id: 'twilight_reading_room',
    label: 'Twilight Reading Room',
    swatches: [Color(0xFF46508A), Color(0xFF8598E9), Color(0xFFE9CC92)],
    primaryLight: Color(0xFF46508A),
    primaryDark: Color(0xFFE9CC92),
    accent: Color(0xFF8598E9),
  );

  static const pinkLemonadeBliss = AppColorPalette(
    id: 'pink_lemonade_bliss',
    label: 'Pink Lemonade Bliss',
    swatches: [Color(0xFFE8965B), Color(0xFFF2B705), Color(0xFFF5D76E)],
    primaryLight: Color(0xFFE8965B),
    primaryDark: Color(0xFFF5D76E),
    accent: Color(0xFFF2B705),
  );

  static const mysteriousPurple = AppColorPalette(
    id: 'mysterious_purple',
    label: 'Mysterious Purple',
    swatches: [Color(0xFF2D1B69), Color(0xFF4B2E83), Color(0xFF6C48B5)],
    primaryLight: Color(0xFF4B2E83),
    primaryDark: Color(0xFF9B7EDE),
    accent: Color(0xFF6C48B5),
  );

  static const greenStrawberryLatte = AppColorPalette(
    id: 'green_strawberry_latte',
    label: 'Green Strawberry Latte',
    swatches: [Color(0xFF7C8B5B), Color(0xFFA8D5BA), Color(0xFFF4A9B8)],
    primaryLight: Color(0xFF7C8B5B),
    primaryDark: Color(0xFFA8D5BA),
    accent: Color(0xFFF4A9B8),
  );

  static const saffronSerenity = AppColorPalette(
    id: 'saffron_serenity',
    label: 'Saffron Serenity',
    swatches: [Color(0xFF3E8E8E), Color(0xFF6FA8DC), Color(0xFFE8B04B)],
    primaryLight: Color(0xFF3E8E8E),
    primaryDark: Color(0xFF6FA8DC),
    accent: Color(0xFFE8B04B),
  );

  static const sakuraBlossom = AppColorPalette(
    id: 'sakura_blossom',
    label: 'Sakura Blossom',
    swatches: [Color(0xFFC2185B), Color(0xFFE85D75), Color(0xFFF4A6B7)],
    primaryLight: Color(0xFFC2185B),
    primaryDark: Color(0xFFF4A6B7),
    accent: Color(0xFFE85D75),
  );

  static const List<AppColorPalette> all = [
    twilightReadingRoom,
    pinkLemonadeBliss,
    mysteriousPurple,
    greenStrawberryLatte,
    saffronSerenity,
    sakuraBlossom,
  ];

  static AppColorPalette byId(String? id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => twilightReadingRoom,
    );
  }
}