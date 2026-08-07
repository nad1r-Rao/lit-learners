import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/drawing_stroke.dart';

/// Holds every mark on a canvas plus the currently selected tool.
///
/// Kept separate from the level view models so the same canvas can be reused
/// by the free-drawing activities and the letter tracing activities.
class DrawingCanvasController extends ChangeNotifier {
  DrawingCanvasController({
    DrawingTool tool = DrawingTool.pen,
    Color? color,
    DrawingWidth width = DrawingWidth.medium,
    this.availableTools = defaultTools,
  })  : _tool = tool,
        _color = color ?? palette.first,
        _width = width;

  static const defaultTools = DrawingTool.values;

  /// Bright, high-contrast colours that read well on the white canvas.
  static const palette = <Color>[
    AppColors.ink,
    AppColors.coral,
    AppColors.honey,
    AppColors.leaf,
    AppColors.sky,
    AppColors.violet,
    AppColors.rose,
    AppColors.aqua,
    AppColors.lime,
    Color(0xFF9C5B2E),
  ];

  final List<DrawingTool> availableTools;

  final List<DrawingStroke> _strokes = <DrawingStroke>[];
  final List<DrawingStroke> _redoStack = <DrawingStroke>[];
  DrawingStroke? _activeStroke;
  DrawingTool _tool;
  Color _color;
  DrawingWidth _width;
  int _revision = 0;

  DrawingTool get tool => _tool;
  Color get color => _color;
  DrawingWidth get width => _width;
  int get revision => _revision;

  /// Committed strokes plus the in-progress one, ready to paint.
  List<DrawingStroke> get strokes => [
        ..._strokes,
        if (_activeStroke != null) _activeStroke!,
      ];

  /// Strokes that actually left ink behind (an eraser-only canvas is blank).
  int get inkStrokeCount =>
      strokes.where((stroke) => !stroke.tool.isEraser).length;

  bool get hasInk => inkStrokeCount > 0;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isDrawing => _activeStroke != null;

  void selectTool(DrawingTool value) {
    if (_tool == value) return;
    _tool = value;
    _bump();
  }

  void selectColor(Color value) {
    // Picking a colour while erasing means the child wants to draw again.
    if (_tool.isEraser) _tool = DrawingTool.pen;
    _color = value;
    _bump();
  }

  void selectWidth(DrawingWidth value) {
    if (_width == value) return;
    _width = value;
    _bump();
  }

  void beginStroke(Offset point, {double pressure = 1}) {
    _activeStroke = DrawingStroke(
      tool: _tool,
      color: _color,
      width: _widthFor(pressure),
    )..add(point, pressure: pressure);
    _redoStack.clear();
    _bump();
  }

  void extendStroke(Offset point, {double pressure = 1}) {
    final stroke = _activeStroke;
    if (stroke == null) return;

    // Drop samples that are too close together: fewer points, smoother curve.
    final last = stroke.points.last;
    if ((point - last).distanceSquared < 1.5) return;

    stroke.add(point, pressure: pressure);
    _bump();
  }

  void endStroke() {
    final stroke = _activeStroke;
    if (stroke == null) return;

    _activeStroke = null;
    _strokes.add(stroke);
    _bump();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redoStack.add(_strokes.removeLast());
    _bump();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _strokes.add(_redoStack.removeLast());
    _bump();
  }

  void clear() {
    if (_strokes.isEmpty && _activeStroke == null) return;
    _strokes.clear();
    _redoStack.clear();
    _activeStroke = null;
    _bump();
  }

  /// Pressure-sensitive tools thicken slightly with a firmer press.
  double _widthFor(double pressure) {
    if (!_tool.respondsToPressure) return _width.value;
    final normalized = pressure.clamp(0.0, 1.0);
    return _width.value * (0.75 + (normalized * 0.5));
  }

  void _bump() {
    _revision++;
    notifyListeners();
  }
}
