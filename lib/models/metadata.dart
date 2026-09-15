import 'dart:ui';
import 'package:flutter/material.dart';

/// Tag item with per-user scoping and deterministic or custom color.
class Tag {
  final int id;
  final String? ownerId;
  final String name;
  final String color;

  const Tag({
    required this.id,
    this.ownerId,
    required this.name,
    required this.color,
  });

  Color get parsedColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF4A90E2);
    }
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      ownerId: json['owner_id']?.toString(),
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#4a90e2',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'color': color,
      };
}

/// Genre item (global vocabulary).
class Genre {
  final int id;
  final String name;
  final String color;

  const Genre({
    required this.id,
    required this.name,
    required this.color,
  });

  Color get parsedColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFB2BEC3);
    }
  }

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#b2bec3',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
      };
}

/// Content warning item (per-user vocabulary).
class ContentWarning {
  final int id;
  final String? ownerId;
  final String name;

  const ContentWarning({
    required this.id,
    this.ownerId,
    required this.name,
  });

  factory ContentWarning.fromJson(Map<String, dynamic> json) {
    return ContentWarning(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      ownerId: json['owner_id']?.toString(),
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
      };
}

/// Reading status options used across the app.
class ReadingStatus {
  static const String reading = 'Reading';
  static const String finished = 'Finished';
  static const String onHold = 'On Hold';
  static const String planning = 'Planning';
  static const String dropped = 'Dropped';

  static const List<String> all = [
    reading,
    finished,
    onHold,
    planning,
    dropped,
  ];

  static Color colorFor(String status) {
    switch (status) {
      case reading:
        return const Color(0xFF9B7EDE);
      case finished:
        return const Color(0xFF7FC9A0);
      case onHold:
        return const Color(0xFFE8C15C);
      case planning:
        return const Color(0xFF6FA8DC);
      case dropped:
        return const Color(0xFFDD7A6E);
      default:
        return const Color(0xFFB9BEC7);
    }
  }
}