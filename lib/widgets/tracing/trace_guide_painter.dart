import 'package:flutter/material.dart';

import '../../services/tracing/trace_glyph.dart';

/// Paints the dotted letter a child traces over.
///
/// Three layers: a very light letter body so the shape is always readable, a
/// dotted stipple through it (the "dots" to follow), and a thin outline that
/// defines the edges.
///
/// The stipple is made by drawing the solid glyph inside a layer and then
/// punching the gaps out with an even-odd path — a rectangle whose holes are
/// the dots. Doing it this way means no per-glyph vector data is needed, so
/// English letters, digits and Urdu Nastaliq forms all work the same way.
class TraceGuidePainter extends CustomPainter {
  const TraceGuidePainter({
    required this.layout,
    required this.accent,
    this.showGhost = true,
  });

  final TraceGlyphLayout? layout;
  final Color accent;

  /// The pale letter body under the dots. Hidden once the child has passed, so
  /// their own work is what stands out.
  final bool showGhost;

  @override
  void paint(Canvas canvas, Size size) {
    final glyphLayout = layout;
    if (glyphLayout == null || glyphLayout.inkRect.isEmpty) return;

    if (showGhost) {
      glyphLayout.paint(canvas, color: accent.withValues(alpha: 0.08));
    }

    _paintDots(canvas, size, glyphLayout);

    glyphLayout.paint(
      canvas,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.4),
    );
  }

  void _paintDots(Canvas canvas, Size size, TraceGlyphLayout glyphLayout) {
    final spacing = (size.shortestSide / 24).clamp(9.0, 18.0);
    final radius = spacing * 0.32;
    final bounds = Offset.zero & size;

    canvas.saveLayer(bounds, Paint());
    glyphLayout.paint(canvas, color: accent.withValues(alpha: 0.55));
    canvas.drawPath(
      _gapMask(bounds, spacing, radius),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  /// Everything *except* the dots, as one even-odd path: the full rectangle
  /// with a circular hole at every grid point.
  Path _gapMask(Rect bounds, double spacing, double radius) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds);

    for (var y = bounds.top + (spacing / 2); y < bounds.bottom; y += spacing) {
      for (var x = bounds.left + (spacing / 2); x < bounds.right; x += spacing) {
        path.addOval(Rect.fromCircle(center: Offset(x, y), radius: radius));
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(TraceGuidePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.accent != accent ||
        oldDelegate.showGhost != showGhost;
  }
}
