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
import '../../widgets/locked_overlay.dart';
import '../../widgets/play/play.dart';

/// The levels inside a module, as a path a child walks along.
///
/// This was a `ListView` of Material `Card`s wrapping `ListTile`s — the same
/// widget a settings screen uses, and the source of most of the 200-odd
/// "ListTile background color or ink splashes may be invisible" exceptions the
/// app throws at startup.
///
/// A level is now a big numbered disc with its stars beside it, laid out as a
/// path so it is obvious which one comes next. The number is the label: a
/// child who cannot read the title can still see where they are up to.
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

    return Scaffold(
      body: PlayGround(
        color: ground,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              _MapHeader(
                title: module?.title ?? 'Levels',
                textDirection: textDirection,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: levels.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ContextualKoalaGuide(
                        trigger: KoalaGuideTrigger.moduleIntro,
                        audience: KoalaGuideAudience.child,
                        moduleId: widget.moduleId,
                        stage: child == null
                            ? null
                            : AgeStageHelper.stageForAge(child.age),
                        textDirection: textDirection,
                        fallbackMessage: module?.description ??
                            'Choose a level and try one short activity.',
                      );
                    }

                    final level = levels[index - 1];
                    return PopIn(
                      index: index,
                      child: _LevelStop(
                        level: level,
                        stars: learning.starsFor(level.id),
                        canOpen: learning.canOpenLevel(level),
                        canDownload: learning.canDownloadLevel(level),
                        lockReason: learning.lockReasonFor(level),
                        textDirection: textDirection,
                        // Alternate which side the disc sits on, so the list
                        // reads as a winding path rather than as a table.
                        flip: index.isEven,
                        onOpen: () => _openLevel(context, level),
                        onDownload: () => _download(context, level),
                        onLocked: (reason) => _showLocked(context, reason),
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

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.title,
    required this.textDirection,
    required this.onBack,
  });

  final String title;
  final TextDirection textDirection;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          PlayIconButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Go back',
            onPressed: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Directionality(
              textDirection: textDirection,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: LearningTextDirection.alignFor(textDirection),
                style: LearningTextDirection.styleFor(
                  const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textDirection,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One stop on the path: a big disc with the level number, and a white card
/// carrying the title, the portion and the stars.
class _LevelStop extends StatelessWidget {
  const _LevelStop({
    required this.level,
    required this.stars,
    required this.canOpen,
    required this.canDownload,
    required this.lockReason,
    required this.textDirection,
    required this.flip,
    required this.onOpen,
    required this.onDownload,
    required this.onLocked,
  });

  final LearningLevel level;
  final int stars;
  final bool canOpen;
  final bool canDownload;
  final String lockReason;
  final TextDirection textDirection;
  final bool flip;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final ValueChanged<String> onLocked;

  @override
  Widget build(BuildContext context) {
    final locked = !canOpen;

    final disc = _LevelDisc(
      number: level.levelNumber,
      locked: locked,
      complete: stars > 0,
    );

    final card = _LevelCard(
      level: level,
      stars: stars,
      locked: locked,
      canDownload: canDownload,
      textDirection: textDirection,
      onDownload: onDownload,
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: flip
          ? [Expanded(child: card), const SizedBox(width: 14), disc]
          : [disc, const SizedBox(width: 14), Expanded(child: card)],
    );

    return Squishy(
      semanticLabel: locked ? '${level.title}, locked' : 'Play ${level.title}',
      onTap: locked && !canDownload ? () => onLocked(lockReason) : onOpen,
      child: Stack(
        children: [
          row,
          // Kept from the original: a locked level has to say *why* it is
          // locked, and the tooltip is the only place that reason appears
          // without tapping.
          if (locked && !canDownload) LockedOverlay(reason: lockReason),
        ],
      ),
    );
  }
}

class _LevelDisc extends StatelessWidget {
  const _LevelDisc({
    required this.number,
    required this.locked,
    required this.complete,
  });

  final int number;
  final bool locked;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final fill = locked
        ? Colors.white.withValues(alpha: 0.4)
        : complete
            ? PlayColors.sunshine
            : Colors.white;

    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 36,
          height: 1,
          fontWeight: FontWeight.w700,
          color: PlayColors.ink.withValues(alpha: locked ? 0.45 : 1),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.stars,
    required this.locked,
    required this.canDownload,
    required this.textDirection,
    required this.onDownload,
  });

  final LearningLevel level;
  final int stars;
  final bool locked;
  final bool canDownload;
  final TextDirection textDirection;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final steps = level.contentItems.length == 1
        ? '1 step'
        : '${level.contentItems.length} steps';
    // Modules that are not a sequence (Story, Drawing) carry no portion, so
    // this falls back to how much there is to work through.
    final portion =
        level.portionLabel == null ? steps : '${level.portionLabel}  ·  $steps';

    return Opacity(
      opacity: locked ? 0.72 : 1,
      child: JellyCard(
        color: Colors.white,
        filled: true,
        borderWidth: 4,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: textDirection == TextDirection.rtl
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: textDirection,
              child: Text(
                level.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: LearningTextDirection.alignFor(textDirection),
                style: LearningTextDirection.styleFor(
                  const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                  textDirection,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PoppingStars(count: stars, size: 26, animate: false),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    portion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: PlayColors.ink.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
            if (canDownload) ...[
              const SizedBox(height: 12),
              PlayButton(
                label: 'Download',
                icon: Icons.download_rounded,
                color: PlayColors.sky,
                onPressed: onDownload,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
