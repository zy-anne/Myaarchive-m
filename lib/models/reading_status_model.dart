import 'package:flutter/material.dart';

/// A user-editable reading status (e.g. Reading, Finished, or a custom one).
class ReadingStatusItem {
  final int id;
  final String ownerId;
  final String name;
  final String color; // hex string, e.g. '#9B7EDE'
  final int position;

  const ReadingStatusItem({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.color,
    this.position = 0,
  });

  Color get parsedColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFB9BEC7);
    }
  }

  factory ReadingStatusItem.fromJson(Map<String, dynamic> json) {
    return ReadingStatusItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      ownerId: json['owner_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#B9BEC7',
      position: json['position'] is int
          ? json['position']
          : int.tryParse(json['position']?.toString() ?? '') ?? 0,
    );
  }

  ReadingStatusItem copyWith({String? name, String? color, int? position}) {
    return ReadingStatusItem(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      color: color ?? this.color,
      position: position ?? this.position,
    );
  }
}