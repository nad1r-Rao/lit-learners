import 'package:flutter/material.dart';

import '../services/tracing/trace_glyph.dart';
import 'drawing_stroke.dart';

/// One finished page of canvas work, kept so a grown-up can look at it on the
/// marking screen after the child hands the device over.
///
/// The marks are held as geometry rather than as a snapshot image: strokes
/// re-render at any size, which is what lets a full-screen canvas appear as a
/// thumbnail beside two others without going near image encoding.
@immutable
class CanvasWork {
  const CanvasWork({
    required this.title,
    required this.prompt,
    required this.canvasSize,
    required this.strokes,
    this.guide,
  });

  /// What the child was asked to make, for example `Letter A`.
  final String title;
  final String prompt;

  /// The size the child actually drew at. [strokes] and [guide] are both in
  /// these coordinates, so the two always line up when replayed together.
  final Size canvasSize;
  final List<DrawingStroke> strokes;

  /// The dotted glyph being traced over, or null for free drawing.
  final TraceGlyphLayout? guide;

  /// False when the page was left blank, or only ever erased.
  bool get hasInk => strokes.any(
        (stroke) => !stroke.tool.isEraser && stroke.points.isNotEmpty,
      );

  bool get isEmpty => canvasSize.isEmpty || !hasInk;
}
