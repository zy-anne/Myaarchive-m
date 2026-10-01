import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/relationship.dart';
import '../theme/app_palette.dart';
import 'cover_image.dart';
import 'relationship_style.dart';

/// Ring-layout graph of character relationships.
///
/// Characters that take part in at least one relationship become avatar
/// nodes on a ring; relationships are curved, colored edges drawn with a
/// [CustomPaint] (same approach as `RadarChart`). Mutual relationships are
/// plain lines, one-way ones get an arrowhead, and conflict types are
/// dashed. Each edge carries a small type-icon badge at its midpoint.
///
/// - Tap a character to highlight its connections (tap empty space to clear).
/// - Tap an edge badge to call [onRelationshipTap] (used to open the editor).
class RelationshipGraph extends StatefulWidget {
  final List<Character> characters;
  final List<Relationship> relationships;
  final ValueChanged<Relationship>? onRelationshipTap;

  const RelationshipGraph({
    super.key,
    required this.characters,
    required this.relationships,
    this.onRelationshipTap,
  });

  @override
  State<RelationshipGraph> createState() => _RelationshipGraphState();
}

class _RelationshipGraphState extends State<RelationshipGraph> {
  static const double _nodeRadius = 22;
  static const double _labelWidth = 76;

  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Only characters with at least one relationship become nodes.
    final connectedIds = <int>{};
    for (final r in widget.relationships) {
      connectedIds
        ..add(r.fromCharacterId)
        ..add(r.toCharacterId);
    }
    final nodes =
        widget.characters.where((c) => connectedIds.contains(c.id)).toList();
    if (nodes.isEmpty) return const SizedBox.shrink();

    final nodeIds = nodes.map((c) => c.id).toSet();
    final edges = widget.relationships
        .where((r) =>
            nodeIds.contains(r.fromCharacterId) &&
            nodeIds.contains(r.toCharacterId) &&
            r.fromCharacterId != r.toCharacterId)
        .toList();
    final hiddenCount = widget.characters.length - nodes.length;
    final selected = nodeIds.contains(_selectedId) ? _selectedId : null;

    // Neighbours of the selected node, so unrelated nodes can be dimmed.
    final neighbours = <int>{};
    if (selected != null) {
      for (final r in edges) {
        if (r.fromCharacterId == selected) neighbours.add(r.toCharacterId);
        if (r.toCharacterId == selected) neighbours.add(r.fromCharacterId);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = math.min(math.max(w, 300.0), 400.0);
          final size = Size(w, h);
          final layout = _GraphLayout.compute(size, nodes, edges, palette);

          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final hit = layout.edgeNear(d.localPosition, 18);
                      if (hit != null) {
                        widget.onRelationshipTap?.call(hit.rel);
                      } else if (_selectedId != null) {
                        setState(() => _selectedId = null);
                      }
                    },
                    child: CustomPaint(
                      size: size,
                      painter: _GraphPainter(layout, selected, palette),
                    ),
                  ),
                ),
                for (final c in nodes)
                  Positioned(
                    left: layout.positions[c.id]!.dx - _labelWidth / 2,
                    top: layout.positions[c.id]!.dy - _nodeRadius,
                    width: _labelWidth,
                    child: _buildNode(
                      c,
                      palette,
                      isSelected: selected == c.id,
                      isDimmed: selected != null &&
                          selected != c.id &&
                          !neighbours.contains(c.id),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        _buildLegend(edges, palette),
        const SizedBox(height: 6),
        Text(
          'Tap a character to highlight their connections · tap a badge on a line to edit'
          '${hiddenCount > 0 ? ' · $hiddenCount character${hiddenCount == 1 ? '' : 's'} with no relationships not shown' : ''}',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: palette.textSecondary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildNode(
    Character c,
    AppPalette palette, {
    required bool isSelected,
    required bool isDimmed,
  }) {
    final hasImage =
        c.profileImagePath != null && c.profileImagePath!.trim().isNotEmpty;
    final initial = c.name.trim().isEmpty ? '?' : c.name.trim()[0].toUpperCase();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedId = isSelected ? null : c.id),
      child: Opacity(
        opacity: isDimmed ? 0.35 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _nodeRadius * 2,
              height: _nodeRadius * 2,
              decoration: BoxDecoration(
                color: palette.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? palette.accent : palette.border,
                  width: isSelected ? 2.4 : 1.4,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? CoverImage(
                      imagePath: c.profileImagePath,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(_nodeRadius),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: palette.accent,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? palette.accent : palette.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(List<Relationship> edges, AppPalette palette) {
    final seen = <String, RelationshipStyle>{};
    for (final r in edges) {
      final s = relationshipStyleFor(r.type, palette);
      seen.putIfAbsent(s.category, () => s);
    }
    final hasOneWay = edges.any((r) => !r.isBidirectional);

    Widget item(IconData icon, Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        ...seen.values.map((s) => item(s.icon, s.color, s.category)),
        if (hasOneWay)
          item(Icons.arrow_forward_rounded, palette.textSecondary, 'One-way'),
      ],
    );
  }
}

// ─── Layout ────────────────────────────────────────────────────────────

class _Edge {
  final Relationship rel;
  final RelationshipStyle style;
  final Offset start;
  final Offset control;
  final Offset end;

  const _Edge(this.rel, this.style, this.start, this.control, this.end);

  /// Point at t = 0.5 on the quadratic curve.
  Offset get mid => Offset(
        0.25 * start.dx + 0.5 * control.dx + 0.25 * end.dx,
        0.25 * start.dy + 0.5 * control.dy + 0.25 * end.dy,
      );
}

class _GraphLayout {
  static const double nodeRadius = _RelationshipGraphState._nodeRadius;

  final Offset center;
  final double ringRadius;
  final Map<int, Offset> positions;
  final List<_Edge> edges;

  const _GraphLayout(this.center, this.ringRadius, this.positions, this.edges);

  factory _GraphLayout.compute(
    Size size,
    List<Character> nodes,
    List<Relationship> rels,
    AppPalette palette,
  ) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave room for the avatar plus its name label below.
    final ringRadius =
        math.max(0.0, math.min(size.width, size.height) / 2 - (nodeRadius + 22));

    final positions = <int, Offset>{};
    final n = nodes.length;
    for (var i = 0; i < n; i++) {
      if (n == 1) {
        positions[nodes[i].id] = center;
      } else {
        final a = -math.pi / 2 + 2 * math.pi * i / n;
        positions[nodes[i].id] =
            center + Offset(math.cos(a), math.sin(a)) * ringRadius;
      }
    }

    // Group edges by unordered pair so A→B and B→A (or several types
    // between the same two people) fan out instead of overlapping.
    final groups = <String, List<Relationship>>{};
    for (final r in rels) {
      final lo = math.min(r.fromCharacterId, r.toCharacterId);
      final hi = math.max(r.fromCharacterId, r.toCharacterId);
      groups.putIfAbsent('$lo-$hi', () => []).add(r);
    }

    final edges = <_Edge>[];
    for (final group in groups.values) {
      final count = group.length;
      for (var i = 0; i < count; i++) {
        final r = group[i];
        final a = positions[r.fromCharacterId];
        final b = positions[r.toCharacterId];
        if (a == null || b == null) continue;

        final d = b - a;
        final dist = d.distance;
        if (dist < 1) continue;
        final dir = d / dist;
        const gap = nodeRadius + 3;
        final start = a + dir * gap;
        final end = b - dir * gap;

        // Perpendicular taken from a canonical (low id → high id) direction
        // so opposite-direction edges bend to opposite sides.
        final lo = math.min(r.fromCharacterId, r.toCharacterId);
        final hi = math.max(r.fromCharacterId, r.toCharacterId);
        final cd = positions[hi]! - positions[lo]!;
        final cdn = cd / cd.distance;
        final perp = Offset(-cdn.dy, cdn.dx);
        final displacement = (i - (count - 1) / 2) * 36.0;

        final control =
            Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2) + perp * displacement;

        edges.add(_Edge(r, relationshipStyleFor(r.type, palette), start,
            control, end));
      }
    }

    return _GraphLayout(center, ringRadius, positions, edges);
  }

  /// Nearest edge badge within [radius] px of [p], if any.
  _Edge? edgeNear(Offset p, double radius) {
    _Edge? best;
    var bestDist = radius;
    for (final e in edges) {
      final d = (e.mid - p).distance;
      if (d <= bestDist) {
        best = e;
        bestDist = d;
      }
    }
    return best;
  }
}

// ─── Painter ───────────────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  final _GraphLayout layout;
  final int? selectedId;
  final AppPalette palette;

  _GraphPainter(this.layout, this.selectedId, this.palette);

  bool _involves(Relationship r) =>
      selectedId == null ||
      r.fromCharacterId == selectedId ||
      r.toCharacterId == selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    // Faint guide ring behind everything.
    if (layout.positions.length > 2) {
      canvas.drawCircle(
        layout.center,
        layout.ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = palette.border.withValues(alpha: 0.5),
      );
    }

    // Dimmed edges first so highlighted ones draw on top.
    for (final e in layout.edges.where((e) => !_involves(e.rel))) {
      _paintEdge(canvas, e, active: false);
    }
    for (final e in layout.edges.where((e) => _involves(e.rel))) {
      _paintEdge(canvas, e, active: true);
    }
  }

  void _paintEdge(Canvas canvas, _Edge e, {required bool active}) {
    final color = e.style.color.withValues(alpha: active ? 0.9 : 0.14);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = active ? (selectedId != null ? 2.8 : 2.2) : 1.4;

    final path = Path()
      ..moveTo(e.start.dx, e.start.dy)
      ..quadraticBezierTo(e.control.dx, e.control.dy, e.end.dx, e.end.dy);

    if (e.style.dashed) {
      _drawDashed(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    if (!e.rel.isBidirectional) {
      _drawArrowHead(canvas, e.end, e.control, color);
    }

    _drawBadge(canvas, e, active);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint,
      {double dash = 7, double gap = 5}) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d += dash + gap;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset from, Color color) {
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    const len = 9.0;
    const spread = 0.5;
    final p1 =
        tip - Offset(math.cos(angle - spread), math.sin(angle - spread)) * len;
    final p2 =
        tip - Offset(math.cos(angle + spread), math.sin(angle + spread)) * len;
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _drawBadge(Canvas canvas, _Edge e, bool active) {
    final mid = e.mid;
    final color = e.style.color.withValues(alpha: active ? 1 : 0.3);

    canvas.drawCircle(mid, 10, Paint()..color = palette.surfaceLight);
    canvas.drawCircle(
      mid,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color,
    );

    final icon = e.style.icon;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 12,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) => true;
}