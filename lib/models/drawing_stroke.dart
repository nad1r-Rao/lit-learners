import 'package:flutter/material.dart';

/// Tools available on the drawing and tracing canvases.
///
/// Each tool only changes how a stroke is painted; the captured geometry is
/// identical, so a stroke can be re-rendered at any size (used by the tracing
/// scorer when it rasterises a child's work).
enum DrawingTool {
  pen,
  pencil,
  brush,
  highlighter,
  eraser,
}

extension DrawingToolVisuals on DrawingTool {
  String get label => switch (this) {
        DrawingTool.pen => 'Pen',
        DrawingTool.pencil => 'Pencil',
        DrawingTool.brush => 'Brush',
        DrawingTool.highlighter => 'Marker',
        DrawingTool.eraser => 'Eraser',
      };

  IconData get icon => switch (this) {
        DrawingTool.pen => Icons.edit,
        DrawingTool.pencil => Icons.create_outlined,
        DrawingTool.brush => Icons.brush,
        DrawingTool.highlighter => Icons.border_color,
        DrawingTool.eraser => Icons.cleaning_services,
      };

  /// Multiplier applied to the selected [DrawingWidth] so every tool keeps a
  /// recognisable weight even when the child picks the same size.
  double get widthFactor => switch (this) {
        DrawingTool.pen => 1,
        DrawingTool.pencil => 0.55,
        DrawingTool.brush => 1.7,
        DrawingTool.highlighter => 2.6,
        DrawingTool.eraser => 1.8,
      };

  double get opacity => switch (this) {
        DrawingTool.pen => 1,
        DrawingTool.pencil => 0.7,
        DrawingTool.brush => 0.95,
        DrawingTool.highlighter => 0.3,
        DrawingTool.eraser => 1,
      };

  StrokeCap get strokeCap =>
      this == DrawingTool.highlighter ? StrokeCap.square : StrokeCap.round;

  bool get isEraser => this == DrawingTool.eraser;

  /// Tools whose ink varies with how hard/fast the child presses.
  bool get respondsToPressure =>
      this == DrawingTool.brush || this == DrawingTool.pencil;
}

/// Three chunky sizes instead of a slider: easier for small fingers.
enum DrawingWidth { small, medium, large }

extension DrawingWidthValue on DrawingWidth {
  double get value => switch (this) {
        DrawingWidth.small => 6,
        DrawingWidth.medium => 12,
        DrawingWidth.large => 22,
      };

  String get label => switch (this) {
        DrawingWidth.small => 'Thin',
        DrawingWidth.medium => 'Medium',
        DrawingWidth.large => 'Thick',
      };
}

/// A single continuous mark made by one finger press.
class DrawingStroke {
  DrawingStroke({
    required this.tool,
    required this.color,
    required this.width,
    List<Offset>? points,
    List<double>? pressures,
  })  : points = points ?? <Offset>[],
        pressures = pressures ?? <double>[];

  final DrawingTool tool;
  final Color color;

  /// Base width in logical pixels before [DrawingToolVisuals.widthFactor].
  final double width;
  final List<Offset> points;

  /// Parallel to [points]; 1.0 when the device reports no pressure.
  final List<double> pressures;

  double get renderWidth => width * tool.widthFactor;

  bool get isDot => points.length < 2;

  void add(Offset point, {double pressure = 1}) {
    points.add(point);
    pressures.add(pressure);
  }

  DrawingStroke copy() {
    return DrawingStroke(
      tool: tool,
      color: color,
      width: width,
      points: List<Offset>.from(points),
      pressures: List<double>.from(pressures),
    );
  }

  /// Rescales the stroke into a canvas of a different size. Used when a canvas
  /// is laid out at one size and scored at another.
  DrawingStroke scaled(double factor) {
    return DrawingStroke(
      tool: tool,
      color: color,
      width: width * factor,
      points: points.map((point) => point * factor).toList(),
      pressures: List<double>.from(pressures),
    );
  }
}
