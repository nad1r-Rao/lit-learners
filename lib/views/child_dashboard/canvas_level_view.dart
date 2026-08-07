import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../core/utils/module_visuals.dart';
import '../../models/drawing_stroke.dart';
import '../../models/learning_level.dart';
import '../../models/trace_score.dart';
import '../../services/tracing/trace_glyph.dart';
import '../../services/tracing/trace_scorer.dart';
import '../../viewmodels/drawing_canvas_controller.dart';
import '../../viewmodels/level_activity_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import '../../widgets/drawing/drawing_toolbar.dart';
import '../../widgets/tracing/trace_guide_painter.dart';
import 'widgets/activity_chrome.dart';

/// Free drawing: one page that the child keeps adding to as the prompts move
/// on, because drawing levels are written as steps that build a single picture
/// ("draw the sky", then "draw a house under the sky").
class DrawingLevelView extends StatefulWidget {
  const DrawingLevelView({
    required this.level,
    required this.onFinish,
    super.key,
  });

  final LearningLevel level;
  final VoidCallback? onFinish;

  @override
  State<DrawingLevelView> createState() => _DrawingLevelViewState();
}

class _DrawingLevelViewState extends State<DrawingLevelView> {
  final DrawingCanvasController _controller = DrawingCanvasController();
  late final LevelActivityViewModel _activity;
  int _itemIndex = 0;

  /// Ink count when the current prompt started, so each step needs its own
  /// fresh marks rather than crediting what was already on the page.
  int _inkBaseline = 0;
  bool _hasNewInk = false;

  @override
  void initState() {
    super.initState();
    _activity = context.read<LevelActivityViewModel>();
    _itemIndex = _activity.itemIndex;
    _activity.addListener(_onActivityChanged);
    _controller.addListener(_onCanvasChanged);
  }

  @override
  void dispose() {
    _activity.removeListener(_onActivityChanged);
    _controller
      ..removeListener(_onCanvasChanged)
      ..dispose();
    super.dispose();
  }

  void _onActivityChanged() {
    if (_activity.itemIndex == _itemIndex) return;

    setState(() {
      _itemIndex = _activity.itemIndex;
      _inkBaseline = _controller.inkStrokeCount;
      _hasNewInk = false;
    });
  }

  void _onCanvasChanged() {
    final hasNewInk = _controller.inkStrokeCount > _inkBaseline;
    if (hasNewInk == _hasNewInk || !mounted) return;

    setState(() => _hasNewInk = hasNewInk);
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final accent = ModuleVisuals.colorForModuleId(widget.level.moduleId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          CanvasLevelHeader(level: widget.level, accent: accent),
          const SizedBox(height: 10),
          Expanded(child: DrawingCanvas(controller: _controller)),
          const SizedBox(height: 10),
          DrawingToolbar(controller: _controller),
          const SizedBox(height: 10),
          _footer(activity),
        ],
      ),
    );
  }

  Widget _footer(LevelActivityViewModel activity) {
    if (!activity.currentItemComplete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasNewInk)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Draw on the page to finish this step.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          AppPrimaryButton(
            icon: Icons.check,
            label: 'I finished this step',
            onPressed: _hasNewInk ? activity.markCurrentLearned : null,
          ),
        ],
      );
    }

    if (!activity.isLastItem) {
      return AppPrimaryButton(
        icon: Icons.arrow_forward,
        label: 'Next step',
        onPressed: activity.nextItem,
      );
    }

    return AppPrimaryButton(
      icon: Icons.check_circle,
      label: widget.level.quizQuestions.isEmpty ? 'Earn reward' : 'Start quiz',
      onPressed: widget.onFinish,
    );
  }
}

/// Letter and number tracing: a dotted glyph on the canvas, checked for how
/// closely the child followed it.
class TracingLevelView extends StatefulWidget {
  const TracingLevelView({
    required this.level,
    required this.onFinish,
    super.key,
  });

  final LearningLevel level;
  final VoidCallback? onFinish;

  @override
  State<TracingLevelView> createState() => _TracingLevelViewState();
}

class _TracingLevelViewState extends State<TracingLevelView> {
  final DrawingCanvasController _controller = DrawingCanvasController(
    width: DrawingWidth.large,
    availableTools: const [
      DrawingTool.pen,
      DrawingTool.pencil,
      DrawingTool.brush,
      DrawingTool.eraser,
    ],
  );
  late final LevelActivityViewModel _activity;

  TraceGlyphLayout? _layout;
  Size _canvasSize = Size.zero;
  Size? _requestedSize;
  String? _requestedGlyph;
  int _itemIndex = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _activity = context.read<LevelActivityViewModel>();
    _itemIndex = _activity.itemIndex;
    _activity.addListener(_onActivityChanged);
    _controller.addListener(_onCanvasChanged);
  }

  @override
  void dispose() {
    _activity.removeListener(_onActivityChanged);
    _controller
      ..removeListener(_onCanvasChanged)
      ..dispose();
    super.dispose();
  }

  void _onActivityChanged() {
    if (_activity.itemIndex == _itemIndex || !mounted) return;

    // Every letter gets a clean page and its own fitted guide.
    _itemIndex = _activity.itemIndex;
    _controller.clear();
    setState(() {
      _layout = null;
      _requestedGlyph = null;
      _requestedSize = null;
    });
  }

  void _onCanvasChanged() {
    // Drawing again means the child is retrying, so drop the stale verdict.
    if (!_controller.isDrawing) return;
    if (_activity.lastTraceScore == null) return;
    if (_activity.currentItemComplete) return;

    _activity.clearTraceFeedback();
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final glyph = activity.currentItem.displayText;
    final accent = ModuleVisuals.colorForModuleId(widget.level.moduleId);
    final result = activity.lastTraceScore;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          CanvasLevelHeader(level: widget.level, accent: accent),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _scheduleLayout(
                  Size(constraints.maxWidth, constraints.maxHeight),
                  glyph,
                );

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DrawingCanvas(
                      controller: _controller,
                      enabled: !_checking,
                      background: TraceGuidePainter(
                        layout: _layout,
                        accent: accent,
                        showGhost: !activity.currentItemComplete,
                      ),
                    ),
                    if (_layout == null)
                      const Center(child: CircularProgressIndicator()),
                  ],
                );
              },
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 10),
            _TraceResultBanner(
              score: result,
              passingScore: widget.level.passingScore,
              attemptsLeft: LevelActivityViewModel.maxTraceAttempts -
                  activity.traceAttempts,
            ),
          ],
          const SizedBox(height: 10),
          DrawingToolbar(controller: _controller),
          const SizedBox(height: 10),
          _footer(activity),
        ],
      ),
    );
  }

  void _scheduleLayout(Size size, String glyph) {
    if (size.isEmpty) return;
    if (_requestedSize == size && _requestedGlyph == glyph) return;

    _requestedSize = size;
    _requestedGlyph = glyph;
    // Fitting the glyph rasterises it once to find its true ink bounds, so it
    // cannot run inside build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveLayout(size, glyph);
    });
  }

  Future<void> _resolveLayout(Size size, String glyph) async {
    final layout = await TraceGlyph.resolve(glyph: glyph, size: size);
    if (!mounted) return;
    if (_requestedSize != size || _requestedGlyph != glyph) return;

    setState(() {
      _layout = layout;
      _canvasSize = size;
    });
  }

  Future<void> _check() async {
    final layout = _layout;
    if (layout == null || _checking) return;

    setState(() => _checking = true);
    final score = await TraceScorer.evaluate(
      layout: layout,
      canvasSize: _canvasSize,
      strokes: _controller.strokes,
    );
    if (!mounted) return;

    setState(() => _checking = false);
    _activity.recordTraceAttempt(score);
  }

  void _startOver() {
    _controller.clear();
    _activity.clearTraceFeedback();
  }

  Widget _footer(LevelActivityViewModel activity) {
    if (!activity.currentItemComplete) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _checking ? null : _startOver,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Start over'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: AppPrimaryButton(
              icon: _checking ? Icons.hourglass_top : Icons.fact_check,
              label: _checking ? 'Checking…' : 'Check my tracing',
              onPressed: _checking ? null : _check,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _checking ? null : _startOver,
            icon: const Icon(Icons.gesture, size: 18),
            label: const Text('Trace again'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: activity.isLastItem
              ? AppPrimaryButton(
                  icon: Icons.check_circle,
                  label: widget.level.quizQuestions.isEmpty
                      ? 'Earn reward'
                      : 'Start quiz',
                  onPressed: widget.onFinish,
                )
              : AppPrimaryButton(
                  icon: Icons.arrow_forward,
                  label: 'Next letter',
                  onPressed: activity.nextItem,
                ),
        ),
      ],
    );
  }
}

/// Compact card header for canvas activities: the glyph, the instruction, the
/// audio cue and how far through the level the child is.
class CanvasLevelHeader extends StatelessWidget {
  const CanvasLevelHeader({
    required this.level,
    required this.accent,
    super.key,
  });

  final LearningLevel level;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final item = activity.currentItem;
    final textDirection = LearningTextDirection.forLevel(level);
    final total = level.contentItems.length;
    final progress =
        (activity.itemIndex + (activity.currentItemComplete ? 1 : 0)) / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ActivityBadge(text: item.displayText, size: 56, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: textDirection == TextDirection.rtl
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: textDirection,
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              LearningTextDirection.alignFor(textDirection),
                          style: LearningTextDirection.styleFor(
                            Theme.of(context).textTheme.titleMedium,
                            textDirection,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Directionality(
                        textDirection: textDirection,
                        child: Text(
                          item.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              LearningTextDirection.alignFor(textDirection),
                          style: LearningTextDirection.styleFor(
                            Theme.of(context).textTheme.bodySmall,
                            textDirection,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ContentAudioButton(audioCueKey: item.audioCueKey),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${activity.itemIndex + 1}/$total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TraceResultBanner extends StatelessWidget {
  const _TraceResultBanner({
    required this.score,
    required this.passingScore,
    required this.attemptsLeft,
  });

  final TraceScore score;
  final int passingScore;
  final int attemptsLeft;

  @override
  Widget build(BuildContext context) {
    final passed = score.passed(passingScore);
    final accent = !score.hasInk
        ? AppColors.sky
        : passed
            ? AppColors.leaf
            : AppColors.honey;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: 0.12), AppColors.panel),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            !score.hasInk
                ? Icons.info_outline
                : passed
                    ? Icons.emoji_events
                    : Icons.favorite,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.feedback(passingScore),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (score.hasInk) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Traced ${(score.coverage * 100).round()}% of the letter · '
                    '${(score.precision * 100).round()}% on the dots'
                    '${passed || attemptsLeft <= 0 ? '' : ' · $attemptsLeft '
                        'tr${attemptsLeft == 1 ? 'y' : 'ies'} left'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (score.hasInk) ...[
            const SizedBox(width: 10),
            Text(
              '${score.score}%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
