import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/drawing_stroke.dart';

/// Shared stroke rendering used by the live canvas and by the offscreen
/// rasteriser in the tracing scorer, so what a child sees is exactly what gets
/// measured.
class StrokePainting {
  const StrokePainting._();

  /// Smooths the raw finger samples with a quadratic through their midpoints.
  static Path pathFor(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points.first.dx, points.first.dy);
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final midpoint = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  static Paint paintFor(
    DrawingStroke stroke, {
    bool asMask = false,
    double widthBoost = 0,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = stroke.tool.strokeCap
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.renderWidth + widthBoost
      ..isAntiAlias = true;

    if (stroke.tool.isEraser) {
      // Erases previously drawn ink; requires the caller to be inside a layer.
      paint
        ..blendMode = BlendMode.clear
        ..color = const Color(0xFF000000);
      return paint;
    }

    if (asMask) {
      // The scorer only cares where ink landed, not how it looks, so every
      // tool contributes at full opacity and without softening.
      paint.color = const Color(0xFFFFFFFF);
      return paint;
    }

    paint.color = stroke.color.withValues(alpha: stroke.tool.opacity);
    if (stroke.tool == DrawingTool.brush) {
      paint.maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        stroke.renderWidth * 0.06,
      );
    }
    return paint;
  }

  /// Paints [strokes] onto [canvas]. Wraps everything in a layer so eraser
  /// strokes clear ink instead of painting black.
  ///
  /// [widthBoost] fattens every mark, which the tracing scorer uses to judge
  /// where a child drew rather than how thick their pen was.
  static void paintStrokes(
    Canvas canvas,
    Size size,
    List<DrawingStroke> strokes, {
    bool asMask = false,
    double widthBoost = 0,
  }) {
    if (strokes.isEmpty) return;

    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = paintFor(stroke, asMask: asMask, widthBoost: widthBoost);

      if (stroke.isDot) {
        final dotPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = paint.color
          ..blendMode = paint.blendMode
          ..maskFilter = paint.maskFilter
          ..isAntiAlias = true;
        canvas.drawCircle(
          stroke.points.first,
          paint.strokeWidth / 2,
          dotPaint,
        );
        continue;
      }

      canvas.drawPath(pathFor(stroke.points), paint);
    }
    canvas.restore();
  }
}

/// Renders committed strokes plus the stroke currently under the finger.
class StrokeCanvasPainter extends CustomPainter {
  const StrokeCanvasPainter({
    required this.strokes,
    required this.revision,
  });

  final List<DrawingStroke> strokes;

  /// Bumped by the controller on every change so repaints are cheap to decide.
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    StrokePainting.paintStrokes(canvas, size, strokes);
  }

  @override
  bool shouldRepaint(StrokeCanvasPainter oldDelegate) {
    return oldDelegate.revision != revision;
  }
}
