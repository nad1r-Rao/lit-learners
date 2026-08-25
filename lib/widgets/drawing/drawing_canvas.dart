import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../viewmodels/drawing_canvas_controller.dart';
import 'stroke_painter.dart';

/// The paper. Captures finger input and paints the controller's strokes.
///
/// [background] is painted underneath the ink and is where the tracing guide
/// (the dotted letter) goes.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    required this.controller,
    this.background,
    this.enabled = true,
    super.key,
  });

  final DrawingCanvasController controller;
  final CustomPainter? background;
  final bool enabled;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  int? _activePointer;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? _onPointerDown : null,
      onPointerMove: widget.enabled ? _onPointerMove : null,
      onPointerUp: widget.enabled ? _onPointerUp : null,
      onPointerCancel: widget.enabled ? _onPointerCancel : null,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.background != null)
                RepaintBoundary(
                  child: CustomPaint(painter: widget.background),
                ),
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: StrokeCanvasPainter(
                        strokes: widget.controller.strokes,
                        revision: widget.controller.revision,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    // One finger at a time keeps strokes from crossing when a palm lands.
    if (_activePointer != null) return;

    _activePointer = event.pointer;
    widget.controller.beginStroke(
      _localPosition(event.position),
      pressure: _normalizedPressure(event),
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;

    widget.controller.extendStroke(
      _localPosition(event.position),
      pressure: _normalizedPressure(event),
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;

    _activePointer = null;
    widget.controller.endStroke();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;

    _activePointer = null;
    widget.controller.endStroke();
  }

  Offset _localPosition(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return globalPosition;
    return box.globalToLocal(globalPosition);
  }

  double _normalizedPressure(PointerEvent event) {
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0) return 1;
    return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
  }
}
