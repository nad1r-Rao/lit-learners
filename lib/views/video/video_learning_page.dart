import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';
import '../../widgets/locked_overlay.dart';
import '../../widgets/star_rating.dart';

class VideoLearningPage extends StatefulWidget {
  const VideoLearningPage({
    required this.moduleId,
    super.key,
  });

  final String moduleId;

  @override
  State<VideoLearningPage> createState() => _VideoLearningPageState();
}

class _VideoLearningPageState extends State<VideoLearningPage> {
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

    return Scaffold(
      body: PlayGround(
        color: PlayColors.bubblegum,
        safeArea: false,
        child: SafeArea(
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Row(
              children: [
                PlayIconButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: 'Go back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    module?.title ?? 'Video Learning',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.moduleIntro,
              audience: KoalaGuideAudience.child,
              moduleId: widget.moduleId,
              stage:
                  child == null ? null : AgeStageHelper.stageForAge(child.age),
              fallbackMessage:
                  'Watch one short lesson at a time, then answer a tiny '
                  'quiz to earn stars.',
            ),
            const SizedBox(height: 16),
            for (final level in levels)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VideoLevelCard(level: level),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

/// One video lesson. Was a `ListTile` with a 24px play glyph; now a chunky
/// row with a 56px play disc, which is what a small finger actually aims at.
class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Squishy(
        semanticLabel: 'Play $title',
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PlayColors.bubblegum.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(PlayMotion.radius),
            border: Border.all(
              color: PlayColors.bubblegum.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: PlayColors.bubblegum,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoLevelCard extends StatelessWidget {
  const _VideoLevelCard({required this.level});

  final LearningLevel level;

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningViewModel>();
    final canOpen = learning.canOpenLevel(level);
    final canDownload = learning.canDownloadLevel(level);
    final reason = learning.lockReasonFor(level);

    return Stack(
      children: [
        JellyCard(
          color: Colors.white,
          filled: true,
          borderWidth: 4,
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PlayColors.bubblegum,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Text(
                        level.levelNumber.toString(),
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.title,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              color: PlayColors.ink,
                            ),
                          ),
                          Text(level.subtitle),
                        ],
                      ),
                    ),
                    StarRating(count: learning.starsFor(level.id)),
                  ],
                ),
                // Video levels can ship undownloaded just like the other
                // modules, so they need the same way to fetch them.
                if (canDownload) ...[
                  const SizedBox(height: 12),
                  PlayButton(
                    onPressed: () => _download(context, learning),
                    icon: Icons.download_rounded,
                    label: 'Download',
                    color: PlayColors.sky,
                  ),
                ],
                const SizedBox(height: 12),
                for (final lesson in level.videoLessons)
                  _LessonRow(
                    title: lesson.title,
                    subtitle:
                        '${lesson.durationLabel} - ${lesson.description}',
                    onTap: () {
                      if (!canOpen) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(reason)),
                        );
                        return;
                      }
                      Navigator.of(context).pushNamed(
                        RouteNames.videoPlayer,
                        arguments: VideoPlayerArgs(
                          levelId: level.id,
                          lesson: lesson,
                        ),
                      );
                    },
                  ),
              ],
            ),
        ),
        // A downloadable level is not really locked: covering it would hide
        // the download button the parent needs to tap.
        if (!canOpen && !canDownload) LockedOverlay(reason: reason),
      ],
    );
  }

  Future<void> _download(
    BuildContext context,
    LearningViewModel learning,
  ) async {
    await learning.downloadLevel(level);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${level.title} downloaded.')),
    );
  }
}
