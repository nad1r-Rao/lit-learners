import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/drawing_stroke.dart';
import 'package:little_learners/models/trace_score.dart';
import 'package:little_learners/services/tracing/trace_glyph.dart';
import 'package:little_learners/services/tracing/trace_scorer.dart';

const _canvas = Size(400, 400);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TraceGlyph', () {
    setUp(TraceGlyph.clearCache);

    test('fits the glyph inside the canvas and centres its ink', () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);

      expect(layout.inkRect.isEmpty, isFalse);
      expect(layout.inkRect.width, lessThanOrEqualTo(_canvas.width));
      expect(layout.inkRect.height, lessThanOrEqualTo(_canvas.height));
      expect(layout.inkRect.center.dx, closeTo(_canvas.width / 2, 1));
      expect(layout.inkRect.center.dy, closeTo(_canvas.height / 2, 1));
    });

    test('the glyph fills most of the canvas without touching the edges',
        () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);
      final longestSide = layout.inkRect.longestSide;

      expect(longestSide, greaterThan(_canvas.shortestSide * 0.6));
      expect(longestSide, lessThanOrEqualTo(_canvas.shortestSide * 0.75));
    });

    test('an Urdu glyph resolves right-to-left with the Nastaliq font',
        () async {
      final layout = await TraceGlyph.resolve(glyph: 'ب', size: _canvas);

      expect(layout.textDirection, TextDirection.rtl);
      expect(layout.fontFamily, 'NotoNastaliqUrdu');
      expect(layout.inkRect.isEmpty, isFalse);
    });
  });

  group('TraceScorer', () {
    setUp(TraceGlyph.clearCache);

    test('a blank canvas scores nothing and reports no ink', () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);
      final score = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: const [],
      );

      expect(score.hasInk, isFalse);
      expect(score.score, 0);
      expect(score.passed(50), isFalse);
    });

    test('covering the letter closely scores near full marks', () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);
      final score = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: _fill(layout.inkRect),
      );

      expect(score.hasInk, isTrue);
      expect(score.coverage, greaterThan(0.8));
      expect(score.precision, greaterThan(0.85));
      expect(score.score, greaterThan(90));
    });

    test('drawing away from the letter scores badly', () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);
      final ink = layout.inkRect;
      final band = _canvas.shortestSide * TraceScorer.defaultToleranceRatio;
      // Clear of the letter by more than the tolerance, above and below it.
      final above = ink.top - band - 12;
      final below = ink.bottom + band + 12;

      final score = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: [
          _line(Offset(ink.left, above), Offset(ink.right, above), width: 8),
          _line(Offset(ink.left, below), Offset(ink.right, below), width: 8),
        ],
      );

      expect(score.hasInk, isTrue);
      expect(score.coverage, lessThan(0.05));
      expect(score.precision, lessThan(0.05));
      expect(score.score, lessThan(10));
    });

    test('tracing only part of the letter scores below a full trace',
        () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);
      final ink = layout.inkRect;
      final topHalf = Rect.fromLTRB(
        ink.left,
        ink.top,
        ink.right,
        ink.center.dy,
      );

      final partial = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: _fill(topHalf),
      );
      final full = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: _fill(ink),
      );

      expect(partial.coverage, lessThan(full.coverage));
      expect(partial.score, lessThan(full.score));
      // Staying on the letter still counts, so precision holds up.
      expect(partial.precision, greaterThan(0.85));
    });

    test('a small overshoot past the letter is forgiven', () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);
      final overshot = layout.inkRect.inflate(6);

      final score = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: _fill(overshot),
      );

      expect(score.precision, greaterThan(0.85));
      expect(score.passed(60), isTrue);
    });

    test('an eraser stroke removes ink before grading', () async {
      final layout = await TraceGlyph.resolve(glyph: 'A', size: _canvas);
      final strokes = _fill(layout.inkRect)
        ..add(
          _line(
            Offset(layout.inkRect.left, layout.inkRect.center.dy),
            Offset(layout.inkRect.right, layout.inkRect.center.dy),
            width: 40,
            tool: DrawingTool.eraser,
          ),
        );

      final erased = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: strokes,
      );
      final intact = await TraceScorer.evaluate(
        layout: layout,
        canvasSize: _canvas,
        strokes: _fill(layout.inkRect),
      );

      expect(erased.coverage, lessThan(intact.coverage));
    });
  });

  group('TraceScore', () {
    test('passing needs both ink and the level threshold', () {
      const score = TraceScore(
        coverage: 0.8,
        precision: 0.9,
        score: 70,
        hasInk: true,
      );

      expect(score.passed(60), isTrue);
      expect(score.passed(75), isFalse);
      expect(const TraceScore.empty().passed(0), isFalse);
    });

    test('feedback points at whichever part went wrong', () {
      const missedMost = TraceScore(
        coverage: 0.2,
        precision: 0.9,
        score: 20,
        hasInk: true,
      );
      const wandered = TraceScore(
        coverage: 0.7,
        precision: 0.3,
        score: 40,
        hasInk: true,
      );

      expect(missedMost.feedback(60), contains('whole letter'));
      expect(wandered.feedback(60), contains('on the dots'));
      expect(const TraceScore.empty().feedback(60), contains('Draw on the dots'));
    });
  });
}

DrawingStroke _line(
  Offset from,
  Offset to, {
  double width = 12,
  DrawingTool tool = DrawingTool.pen,
}) {
  return DrawingStroke(
    tool: tool,
    color: const Color(0xFF000000),
    width: width,
  )
    ..add(from)
    ..add(to);
}

/// Horizontal strokes packed tightly enough to colour [rect] in.
List<DrawingStroke> _fill(Rect rect, {double width = 12, double spacing = 8}) {
  final strokes = <DrawingStroke>[];
  final inset = width / 2;
  for (var y = rect.top + inset; y <= rect.bottom - inset; y += spacing) {
    strokes.add(
      _line(
        Offset(rect.left + inset, y),
        Offset(rect.right - inset, y),
        width: width,
      ),
    );
  }
  return strokes;
}
