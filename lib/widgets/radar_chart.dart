import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class RadarChartData {
  final String label;
  final double value;
  const RadarChartData(this.label, this.value);
}

class RadarChart extends StatelessWidget {
  final List<RadarChartData> data;
  final double size;

  const RadarChart({super.key, required this.data, this.size = 260});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RadarChartPainter(data)),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<RadarChartData> data;
  _RadarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 3) return; // needs at least a triangle to read sensibly
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 28; // leave room for labels
    final n = data.length;
    final maxVal = data.map((d) => d.value).fold<double>(0, (a, b) => a > b ? a : b);
    final angleStep = (2 * math.pi) / n;

    Offset pointFor(int i, double fraction) {
      final angle = -math.pi / 2 + angleStep * i;
      return Offset(
        center.dx + radius * fraction * math.cos(angle),
        center.dy + radius * fraction * math.sin(angle),
      );
    }

    // grid rings
    final gridPaint = Paint()
      ..color = AppColors.darkBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ring in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = pointFor(i, ring);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // axis lines + labels
    final axisPaint = Paint()..color = AppColors.darkBorder..strokeWidth = 1;
    for (int i = 0; i < n; i++) {
      final p = pointFor(i, 1.0);
      canvas.drawLine(center, p, axisPaint);

      final labelPoint = pointFor(i, 1.16);
      final tp = TextPainter(
        text: TextSpan(text: data[i].label,
            style: TextStyle(color: AppColors.darkTextMuted, fontSize: 10)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelPoint.dx - tp.width / 2, labelPoint.dy - tp.height / 2));
    }

    if (maxVal <= 0) return;

    // data polygon
    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final p = pointFor(i, (data[i].value / maxVal).clamp(0.0, 1.0));
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()..color = AppColors.primary.withValues(alpha: 0.28));
    canvas.drawPath(dataPath, Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    final dotPaint = Paint()..color = AppColors.primaryLight;
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(pointFor(i, (data[i].value / maxVal).clamp(0.0, 1.0)), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter old) => old.data != data;
}