import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Icon + color (+ line style) used to visually distinguish a relationship's
/// type, shared by the list cards, the graph view, and the editor.
class RelationshipStyle {
  final String category;
  final IconData icon;
  final Color color;

  /// Conflict-type edges are drawn dashed in the graph so they can be told
  /// apart from romantic ones, which share the same (danger) color.
  final bool dashed;

  const RelationshipStyle(this.category, this.icon, this.color,
      {this.dashed = false});
}

/// Suggested types offered as quick-pick chips in the relationship editor.
/// `type` is still free text — anything typed is accepted.
const List<String> kSuggestedRelationshipTypes = [
  'Friend',
  'Family',
  'Sibling',
  'Romantic',
  'Rival',
  'Enemy',
  'Mentor',
  'Ally',
];

/// Maps a free-text relationship [type] to its style via case-insensitive
/// substring matching. Unrecognized types fall back to the neutral
/// "Friend / Other" style in the palette's accent color.
RelationshipStyle relationshipStyleFor(String type, AppPalette palette) {
  final t = type.trim().toLowerCase();

  if (t.contains('romant') ||
      t.contains('spouse') ||
      t.contains('crush') ||
      t.contains('love') ||
      t.contains('partner')) {
    return RelationshipStyle('Romantic', Icons.favorite_rounded, palette.danger);
  }
  if (t.contains('famil') ||
      t.contains('sibling') ||
      t.contains('parent') ||
      t.contains('child') ||
      t.contains('guardian') ||
      t.contains('brother') ||
      t.contains('sister')) {
    return RelationshipStyle(
        'Family', Icons.family_restroom_rounded, palette.gold);
  }
  if (t.contains('rival') || t.contains('enem') || t.contains('antagon')) {
    return RelationshipStyle(
        'Conflict', Icons.local_fire_department_rounded, palette.danger,
        dashed: true);
  }
  if (t.contains('mentor') || t.contains('ally') || t.contains('teach')) {
    return RelationshipStyle(
        'Mentor / Ally', Icons.shield_rounded, palette.success);
  }
  return RelationshipStyle(
      'Friend / Other', Icons.people_alt_rounded, palette.accent);
}