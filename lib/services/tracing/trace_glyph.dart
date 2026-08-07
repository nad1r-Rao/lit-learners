import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/utils/learning_text_direction.dart';

/// Scale-invariant ink measurements for one glyph rendered in one font.
///
/// A `TextPainter` box is much taller than the letter drawn inside it (font
/// ascent/descent, and Nastaliq is extreme about this), so fitting a glyph by
/// its layout box leaves it small and off-centre. These metrics record where
/// the actual pixels sit inside the box; because fonts scale linearly the ratio
/// holds at every size, so this is measured once per glyph and cached.
@immutable
class GlyphInkMetrics {
  const GlyphInkMetrics({
    required this.referenceFontSize,
    required this.boxSize,
    required this.inkRect,
  });

  final double referenceFontSize;
  final Size boxSize;

  /// Ink bounds relative to the top-left of the painter box.
  final Rect inkRect;

  bool get isEmpty => inkRect.isEmpty;
}

/// A glyph fitted to a specific canvas, ready to paint or rasterise.
@immutable
class TraceGlyphLayout {
  const TraceGlyphLayout({
    required this.glyph,
    required this.fontFamily,
    required this.fontSize,
    required this.origin,
    required this.inkRect,
    required this.textDirection,
  });

  final String glyph;
  final String? fontFamily;
  final double fontSize;

  /// Where the `TextPainter` must be painted for the ink to land on target.
  final Offset origin;

  /// Ink bounds in canvas coordinates — the area the child has to cover.
  final Rect inkRect;
  final TextDirection textDirection;

  /// Builds the painter for this layout. Pass [foreground] to stroke the glyph
  /// outline instead of filling it.
  TextPainter painter({Color color = const Color(0xFF000000), Paint? foreground}) {
    return TraceGlyph.painterFor(
      glyph: glyph,
      fontFamily: fontFamily,
      fontSize: fontSize,
      textDirection: textDirection,
      color: color,
      foreground: foreground,
    )..layout();
  }

  void paint(Canvas canvas, {Color color = const Color(0xFF000000), Paint? foreground}) {
    painter(color: color, foreground: foreground).paint(canvas, origin);
  }

  @override
  bool operator ==(Object other) {
    return other is TraceGlyphLayout &&
        other.glyph == glyph &&
        other.fontFamily == fontFamily &&
        other.fontSize == fontSize &&
        other.origin == origin &&
        other.inkRect == inkRect &&
        other.textDirection == textDirection;
  }

  @override
  int get hashCode => Object.hash(
        glyph,
        fontFamily,
        fontSize,
        origin,
        inkRect,
        textDirection,
      );
}

/// Lays glyphs out for tracing: measures their ink, fits them to the canvas and
/// centres them.
class TraceGlyph {
  const TraceGlyph._();

  static const _referenceFontSize = 140.0;
  static const _alphaThreshold = 16;

  /// Latin letters and digits are traced in the app's display face so the
  /// dotted guide matches the letterforms shown everywhere else. Urdu keeps
  /// its Nastaliq face, chosen by [LearningTextDirection].
  static const latinFontFamily = 'Fredoka';

  /// Fraction of the canvas the glyph should occupy.
  static const defaultFillRatio = 0.74;

  static final Map<String, GlyphInkMetrics> _metricsCache = {};

  static TextPainter painterFor({
    required String glyph,
    required String? fontFamily,
    required double fontSize,
    required TextDirection textDirection,
    Color color = const Color(0xFF000000),
    Paint? foreground,
  }) {
    return TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: foreground == null ? color : null,
          foreground: foreground,
        ),
      ),
      textDirection: textDirection,
      textAlign: TextAlign.center,
    );
  }

  /// Fits [glyph] into [size]. Async because measuring the ink means rendering
  /// the glyph once; the measurement is cached per glyph + font.
  static Future<TraceGlyphLayout> resolve({
    required String glyph,
    required Size size,
    String? fontFamily,
    double fillRatio = defaultFillRatio,
  }) async {
    final textDirection = LearningTextDirection.forText(glyph);
    final resolvedFamily = fontFamily ??
        LearningTextDirection.fontFamilyFor(textDirection) ??
        latinFontFamily;
    final metrics = await _inkMetrics(glyph, resolvedFamily, textDirection);

    if (metrics.isEmpty || size.isEmpty) {
      return TraceGlyphLayout(
        glyph: glyph,
        fontFamily: resolvedFamily,
        fontSize: size.shortestSide * 0.5,
        origin: Offset.zero,
        inkRect: Rect.zero,
        textDirection: textDirection,
      );
    }

    final target = Size(size.width * fillRatio, size.height * fillRatio);
    final scale = [
      target.width / metrics.inkRect.width,
      target.height / metrics.inkRect.height,
    ].reduce((a, b) => a < b ? a : b);

    final fontSize = metrics.referenceFontSize * scale;
    final inkSize = metrics.inkRect.size * scale;
    final inkTopLeft = Offset(
      (size.width - inkSize.width) / 2,
      (size.height - inkSize.height) / 2,
    );
    // The painter draws from the box origin, so back the ink offset out of it.
    final origin = inkTopLeft - (metrics.inkRect.topLeft * scale);

    return TraceGlyphLayout(
      glyph: glyph,
      fontFamily: resolvedFamily,
      fontSize: fontSize,
      origin: origin,
      inkRect: inkTopLeft & inkSize,
      textDirection: textDirection,
    );
  }

  static Future<GlyphInkMetrics> _inkMetrics(
    String glyph,
    String? fontFamily,
    TextDirection textDirection,
  ) async {
    final cacheKey = '${fontFamily ?? 'default'}|$glyph';
    final cached = _metricsCache[cacheKey];
    if (cached != null) return cached;

    final painter = painterFor(
      glyph: glyph,
      fontFamily: fontFamily,
      fontSize: _referenceFontSize,
      textDirection: textDirection,
      color: const Color(0xFFFFFFFF),
    )..layout();

    final width = painter.width.ceil().clamp(1, 1024);
    final height = painter.height.ceil().clamp(1, 1024);

    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();

    final metrics = GlyphInkMetrics(
      referenceFontSize: _referenceFontSize,
      boxSize: Size(width.toDouble(), height.toDouble()),
      inkRect: _inkBounds(byteData, width, height),
    );
    _metricsCache[cacheKey] = metrics;
    return metrics;
  }

  static Rect _inkBounds(ByteData? data, int width, int height) {
    if (data == null) return Rect.zero;

    final bytes = data.buffer.asUint8List();
    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < height; y++) {
      final rowStart = y * width * 4;
      for (var x = 0; x < width; x++) {
        if (bytes[rowStart + (x * 4) + 3] <= _alphaThreshold) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX < 0 || maxY < 0) return Rect.zero;
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
  }

  @visibleForTesting
  static void clearCache() => _metricsCache.clear();
}
