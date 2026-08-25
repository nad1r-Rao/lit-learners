import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/drawing_stroke.dart';
import 'package:little_learners/viewmodels/drawing_canvas_controller.dart';

void main() {
  group('DrawingCanvasController', () {
    test('a stroke is only committed once the finger lifts', () {
      final controller = DrawingCanvasController();

      controller.beginStroke(const Offset(10, 10));
      controller.extendStroke(const Offset(40, 40));

      expect(controller.isDrawing, isTrue);
      expect(controller.strokes, hasLength(1));
      expect(controller.canUndo, isFalse);

      controller.endStroke();

      expect(controller.isDrawing, isFalse);
      expect(controller.canUndo, isTrue);
    });

    test('samples closer than the minimum spacing are dropped', () {
      final controller = DrawingCanvasController();

      controller.beginStroke(const Offset(10, 10));
      controller.extendStroke(const Offset(10.2, 10.2));
      controller.extendStroke(const Offset(60, 60));

      expect(controller.strokes.single.points, hasLength(2));
    });

    test('undo and redo walk the stroke history', () {
      final controller = DrawingCanvasController();

      _drawLine(controller, const Offset(0, 0), const Offset(50, 50));
      _drawLine(controller, const Offset(0, 60), const Offset(50, 90));

      expect(controller.strokes, hasLength(2));

      controller.undo();

      expect(controller.strokes, hasLength(1));
      expect(controller.canRedo, isTrue);

      controller.redo();

      expect(controller.strokes, hasLength(2));
      expect(controller.canRedo, isFalse);
    });

    test('starting a new stroke discards the redo history', () {
      final controller = DrawingCanvasController();

      _drawLine(controller, const Offset(0, 0), const Offset(50, 50));
      controller.undo();
      _drawLine(controller, const Offset(0, 60), const Offset(50, 90));

      expect(controller.canRedo, isFalse);
      expect(controller.strokes, hasLength(1));
    });

    test('clear empties the page and the history', () {
      final controller = DrawingCanvasController();

      _drawLine(controller, const Offset(0, 0), const Offset(50, 50));
      controller.clear();

      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
      expect(controller.hasInk, isFalse);
    });

    test('eraser strokes do not count as ink', () {
      final controller = DrawingCanvasController()
        ..selectTool(DrawingTool.eraser);

      _drawLine(controller, const Offset(0, 0), const Offset(50, 50));

      expect(controller.strokes, hasLength(1));
      expect(controller.hasInk, isFalse);

      controller.selectTool(DrawingTool.pen);
      _drawLine(controller, const Offset(0, 60), const Offset(50, 90));

      expect(controller.hasInk, isTrue);
      expect(controller.inkStrokeCount, 1);
    });

    test('picking a colour while erasing switches back to the pen', () {
      final controller = DrawingCanvasController()
        ..selectTool(DrawingTool.eraser)
        ..selectColor(DrawingCanvasController.palette.last);

      expect(controller.tool, DrawingTool.pen);
      expect(controller.color, DrawingCanvasController.palette.last);
    });

    test('a stroke keeps the tool and colour it started with', () {
      final controller = DrawingCanvasController()
        ..selectTool(DrawingTool.highlighter)
        ..selectColor(DrawingCanvasController.palette[2]);

      _drawLine(controller, const Offset(0, 0), const Offset(50, 50));
      controller.selectTool(DrawingTool.pen);

      final stroke = controller.strokes.single;
      expect(stroke.tool, DrawingTool.highlighter);
      expect(stroke.color, DrawingCanvasController.palette[2]);
      expect(stroke.renderWidth,
          DrawingWidth.medium.value * DrawingTool.highlighter.widthFactor);
    });

    test('pressure only changes the width of pressure-aware tools', () {
      final pen = DrawingCanvasController();
      pen.beginStroke(Offset.zero, pressure: 0.2);
      pen.endStroke();

      expect(pen.strokes.single.width, DrawingWidth.medium.value);

      final brush = DrawingCanvasController(tool: DrawingTool.brush);
      brush.beginStroke(Offset.zero, pressure: 0.2);
      brush.endStroke();

      expect(brush.strokes.single.width, lessThan(DrawingWidth.medium.value));
    });
  });
}

void _drawLine(DrawingCanvasController controller, Offset from, Offset to) {
  controller
    ..beginStroke(from)
    ..extendStroke(to)
    ..endStroke();
}
