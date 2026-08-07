import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/canvas_work.dart';
import '../tracing/trace_guide_painter.dart';
import 'stroke_painter.dart';

/// Replays a page of [CanvasWork] at whatever size it is given.
///
/// The strokes are laid out at their original canvas size inside a [FittedBox],
/// so the guide and the ink stay in register no matter how far the page is
/// scaled down. That is why the work is stored as geometry rather than as an
/// image.
class CanvasWorkPreview extends StatelessWidget {
  const CanvasWorkPreview({
    required this.work,
    required this.accent,
    super.key,
  });

  final CanvasWork work;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: work.canvasSize.isEmpty
            ? const Center(child: Text('Nothing was drawn.'))
            : FittedBox(
                fit: BoxFit.contain,
                child: SizedBox.fromSize(
                  size: work.canvasSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (work.guide != null)
                        CustomPaint(
                          painter: TraceGuidePainter(
                            layout: work.guide,
                            accent: accent,
                            // The parent is judging the child's line, so the
                            // pale letter body is left out and only the dots
                            // and the outline stay behind it.
                            showGhost: false,
                          ),
                        ),
                      CustomPaint(
                        painter: StrokeCanvasPainter(
                          strokes: work.strokes,
                          revision: work.strokes.length,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
