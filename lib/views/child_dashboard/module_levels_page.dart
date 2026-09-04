import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';
import 'widgets/level_map.dart';

/// A module's levels, as a map a child walks rather than a list they scroll.
///
/// This started as a `ListView` of Material `Card`s, then became a column of
/// numbered rows. Both were still a list: four things stacked up, with nothing
/// saying where the child is or how far there is to go.
///
/// It is now a road. The stops are joined by a winding path, the part already
/// walked is filled in behind them, and there is a trophy at the end. Every
/// module gets a different road, derived from its id — see [MapShape].
class ModuleLevelsPage extends StatefulWidget {
  const ModuleLevelsPage({
    required this.moduleId,
    super.key,
  });

  final String moduleId;

  @override
  State<ModuleLevelsPage> createState() => _ModuleLevelsPageState();
}

class _ModuleLevelsPageState extends State<ModuleLevelsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LearningViewModel>().loadLevelsForModule(widget.moduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningViewModel>();
    final child = context.watch<ActiveChildSession>().activeChild;
    final module = learning.moduleById(widget.moduleId);
    final levels = learning.levelsFor(widget.moduleId);
    final ground = PlayColors.forModuleId(widget.moduleId);
    final textDirection = module == null
        ? TextDirection.ltr
        : LearningTextDirection.forModule(module);

    final stops = [
      for (final level in levels)
        LevelStopData(
          level: level,
          stars: learning.starsFor(level.id),
          completed: learning.isLevelCompleted(level.id),
          canOpen: learning.canOpenLevel(level),
          canDownload: learning.canDownloadLevel(level),
          lockReason: learning.lockReasonFor(level),
        ),
    ];
    final done = stops.where((stop) => stop.completed).length;

    return Scaffold(
      body: PlayGround(
        color: ground,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              PlayHeader(
                title: module?.title ?? 'Levels',
                textDirection: textDirection,
                titleStyle: LearningTextDirection.styleFor(
                  const TextStyle(),
                  textDirection,
                ),
                onBack: () => Navigator.of(context).maybePop(),
              ),
              if (stops.isNotEmpty)
                _MapProgress(done: done, total: stops.length),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    children: [
                      ContextualKoalaGuide(
                        trigger: KoalaGuideTrigger.moduleIntro,
                        audience: KoalaGuideAudience.child,
                        moduleId: widget.moduleId,
                        stage: child == null
                            ? null
                            : AgeStageHelper.stageForAge(child.age),
                        textDirection: textDirection,
                        fallbackMessage: module?.description ??
                            'Choose a level and try one short activity.',
                      ),
                      const SizedBox(height: 12),
                      LevelMap(
                        stops: stops,
                        moduleId: widget.moduleId,
                        accent: PlayColors.sunshine,
                        textDirection: textDirection,
                        onOpen: (level) => _openLevel(context, level),
                        onDownload: (level) => _download(context, level),
                        onLocked: (reason) => _showLocked(context, reason),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLevel(BuildContext context, LearningLevel level) {
    Navigator.of(context)
        .pushNamed(RouteNames.levelPlayer, arguments: level.id);
  }

  void _showLocked(BuildContext context, String reason) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }

  Future<void> _download(BuildContext context, LearningLevel level) async {
    await context.read<LearningViewModel>().downloadLevel(level);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${level.title} downloaded.')),
    );
  }
}

/// How far along the map the child is, above it rather than buried in it.
///
/// Digits and a bar, no words: this screen runs in Urdu too, and a count
/// reads the same in both.
class _MapProgress extends StatelessWidget {
  const _MapProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total == 0 ? 0.0 : done / total),
                duration: PlayMotion.enter,
                curve: PlayMotion.settleCurve,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 14,
                    color: PlayColors.sunshine,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$done/$total',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
