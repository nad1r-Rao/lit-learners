import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/drawing_stroke.dart';
import '../../models/trace_score.dart';
import '../../widgets/drawing/stroke_painter.dart';
import 'trace_glyph.dart';

/// Grades a traced glyph by rasterising the guide and the child's ink into two
/// masks and comparing them pixel by pixel.
///
/// Two independent measures, because they catch different mistakes:
///  * coverage  — did the child trace the *whole* letter, or stop halfway?
///  * precision — did the child's line stay *on* the letter, or wander off?
///
/// A raster comparison is used rather than hand-authored stroke paths so the
/// same code grades English letters, digits and Urdu Nastaliq forms without
/// per-glyph data.
class TraceScorer {
  const TraceScorer._();

  /// Masks are compared at a reduced resolution: plenty of detail for grading
  /// and roughly 60k pixels to walk instead of a full-size canvas.
  static const _maxRasterSide = 260.0;
  static const _alphaThreshold = 24;

  /// Covering this much of the letter counts as a full-marks trace. Toddler
  /// fingers never fill a glyph completely, so demanding 100% would make a
  /// perfect score unreachable.
  static const fullCoverage = 0.82;

  /// Precision decides whether a trace was deliberate. Honest tracing lands
  /// almost entirely inside the tolerance band, while colouring the whole page
  /// in lands around half, so the useful range is narrow and near the top —
  /// grading it from zero would score a scribble as a decent attempt.
  static const minPrecision = 0.55;
  static const fullPrecision = 0.93;

  static const coverageWeight = 0.55;
  static const precisionWeight = 0.45;

  /// How far outside the letter a line may stray and still count as "on the
  /// dots", as a fraction of the canvas's shortest side.
  static const defaultToleranceRatio = 0.055;

  /// Coverage is measured against a slightly fattened copy of the child's ink
  /// so the mark counts for where it was drawn, not how thick the chosen tool
  /// happened to be. A careful line with the thin pencil should score as well
  /// as the same line with the fat brush.
  static const coverageDilationRatio = 0.03;

  static Future<TraceScore> evaluate({
    required TraceGlyphLayout layout,
    required Size canvasSize,
    required List<DrawingStroke> strokes,
    double? tolerance,
  }) async {
    final inked = strokes.where((stroke) => stroke.points.isNotEmpty).toList();
    if (canvasSize.isEmpty || layout.inkRect.isEmpty || inked.isEmpty) {
      return const TraceScore.empty();
    }

    final rasterScale = math.min(
      1.0,
      _maxRasterSide / math.max(canvasSize.width, canvasSize.height),
    );
    final width = math.max(1, (canvasSize.width * rasterScale).round());
    final height = math.max(1, (canvasSize.height * rasterScale).round());
    final scaleX = width / canvasSize.width;
    final scaleY = height / canvasSize.height;
    final band = tolerance ?? canvasSize.shortestSide * defaultToleranceRatio;

    final target = await _rasterize(width, height, scaleX, scaleY, (canvas) {
      layout.paint(canvas, color: const Color(0xFFFFFFFF));
    });
    final tolerant = await _rasterize(width, height, scaleX, scaleY, (canvas) {
      // Fill plus a fat outline: the letter grown outward by the tolerance.
      layout.paint(canvas, color: const Color(0xFFFFFFFF));
      layout.paint(
        canvas,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = band * 2
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFFFFF),
      );
    });
    final user = await _rasterize(width, height, scaleX, scaleY, (canvas) {
      StrokePainting.paintStrokes(canvas, canvasSize, inked, asMask: true);
    });
    final reach = await _rasterize(width, height, scaleX, scaleY, (canvas) {
      StrokePainting.paintStrokes(
        canvas,
        canvasSize,
        inked,
        asMask: true,
        widthBoost: canvasSize.shortestSide * coverageDilationRatio * 2,
      );
    });

    return _compare(
      target: target,
      tolerant: tolerant,
      user: user,
      reach: reach,
    );
  }

  static TraceScore _compare({
    required Uint8List target,
    required Uint8List tolerant,
    required Uint8List user,
    required Uint8List reach,
  }) {
    var targetCount = 0;
    var userCount = 0;
    var hitCount = 0;
    var insideCount = 0;

    for (var i = 0; i < target.length; i++) {
      final onTarget = target[i] > _alphaThreshold;

      if (onTarget) {
        targetCount++;
        if (reach[i] > _alphaThreshold) hitCount++;
      }
      if (user[i] > _alphaThreshold) {
        userCount++;
        if (tolerant[i] > _alphaThreshold) insideCount++;
      }
    }

    if (targetCount == 0 || userCount == 0) return const TraceScore.empty();

    final coverage = hitCount / targetCount;
    final precision = insideCount / userCount;
    final coverageScore = (coverage / fullCoverage).clamp(0.0, 1.0);
    final precisionScore =
        ((precision - minPrecision) / (fullPrecision - minPrecision))
            .clamp(0.0, 1.0);

    // Weighted geometric mean, so a trace has to be both complete *and* on the
    // letter. Adding the two instead would let a page-filling scribble ride a
    // perfect coverage score to a pass.
    final score = 100 *
        math.pow(coverageScore, coverageWeight) *
        math.pow(precisionScore, precisionWeight);

    return TraceScore(
      coverage: coverage,
      precision: precision,
      score: score.round().clamp(0, 100),
      hasInk: true,
    );
  }

  /// Draws into an offscreen image and returns just its alpha channel.
  static Future<Uint8List> _rasterize(
    int width,
    int height,
    double scaleX,
    double scaleY,
    void Function(Canvas canvas) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scaleX, scaleY);
    draw(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();

    final alpha = Uint8List(width * height);
    if (byteData == null) return alpha;

    final bytes = byteData.buffer.asUint8List();
    for (var i = 0; i < alpha.length; i++) {
      alpha[i] = bytes[(i * 4) + 3];
    }
    return alpha;
  }
}
