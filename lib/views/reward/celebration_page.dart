import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/module_visuals.dart';
import '../../models/koala_guide_message.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';

/// The moment a child finishes a level.
///
/// This used to be an AppBar titled "Reward", a grey ListView, a Material
/// Card, a static trophy icon and the line "Score: 85%" — a receipt, handed to
/// a two-year-old, for the single biggest emotional payoff in the app.
///
/// Now it is the loudest screen in Little Learners, and the one place the
/// design is deliberately over the top: full-bleed module colour, confetti,
/// stars that arrive one at a time, and one enormous button. The score is kept
/// but demoted — it is information for a parent, not a reward for a child.
class CelebrationPage extends StatelessWidget {
  const CelebrationPage({
    required this.args,
    super.key,
  });

  final CelebrationArgs args;

  @override
  Widget build(BuildContext context) {
    final accent = ModuleVisuals.colorForModuleId(args.moduleId);

    return Scaffold(
      backgroundColor: accent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed colour instead of a white page with a card on it.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: 0.22),
                    accent,
                  ),
                  accent,
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.12),
                    accent,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Banner(starsEarned: args.starsEarned),
                        const SizedBox(height: 18),
                        PoppingStars(count: args.starsEarned, size: 68),
                        const SizedBox(height: 22),
                        _LevelPlaque(
                          levelTitle: args.levelTitle,
                          score: args.score,
                          accent: accent,
                        ),
                        const SizedBox(height: 18),
                        _KoalaSays(moduleId: args.moduleId),
                        const SizedBox(height: 26),
                        _Actions(args: args),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Above everything, ignoring pointers, so it never blocks the
          // buttons a child is trying to reach.
          const ConfettiBurst(),
        ],
      ),
    );
  }
}

/// The headline. Sized to be the first and loudest thing on the screen.
class _Banner extends StatelessWidget {
  const _Banner({required this.starsEarned});

  final int starsEarned;

  @override
  Widget build(BuildContext context) {
    // Three stars deserves a bigger word than one.
    final word = switch (starsEarned) {
      >= 3 => 'PERFECT!',
      2 => 'WELL DONE!',
      1 => 'GOOD JOB!',
      _ => 'YOU DID IT!',
    };

    final title = Column(
      children: [
        _Trophy(starsEarned: starsEarned),
        const SizedBox(height: 14),
        Text(
          word,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 44,
            height: 1.05,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Color(0x4D000000),
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );

    if (PlayMotion.reduced(context)) return title;

    return title
        .animate()
        .scaleXY(
          begin: 0.5,
          end: 1,
          duration: 620.ms,
          curve: PlayMotion.springCurve,
        )
        .fadeIn(duration: 300.ms);
  }
}

class _Trophy extends StatelessWidget {
  const _Trophy({required this.starsEarned});

  final int starsEarned;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 5,
        ),
      ),
      child: Icon(
        starsEarned >= 3
            ? Icons.emoji_events_rounded
            : Icons.celebration_rounded,
        size: 66,
        color: AppColors.honey,
      ),
    );

    if (PlayMotion.reduced(context)) return badge;

    // A slow rock, not a spin. Enough to feel alive while a child looks at it.
    return badge
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .rotate(
          begin: -0.03,
          end: 0.03,
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}

/// What was finished, and the score, in that order of prominence.
class _LevelPlaque extends StatelessWidget {
  const _LevelPlaque({
    required this.levelTitle,
    required this.score,
    required this.accent,
  });

  final String levelTitle;
  final int? score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return PopIn(
      index: 3,
      child: JellyCard(
        color: accent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: [
            Text(
              levelTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 22,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            if (score != null) ...[
              const SizedBox(height: 8),
              // Deliberately small: the child already knows they did well from
              // the stars and the confetti. This line is for the grown-up.
              Text(
                'Score $score%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink.withValues(alpha: 0.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KoalaSays extends StatelessWidget {
  const _KoalaSays({required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context) {
    return PopIn(
      index: 4,
      child: ContextualKoalaGuide(
        trigger: KoalaGuideTrigger.levelComplete,
        audience: KoalaGuideAudience.child,
        moduleId: moduleId,
        fallbackMessage: 'Great work. Your reward is saved.',
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.args});

  final CelebrationArgs args;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One obvious primary action, at a size a small hand cannot miss.
        PopIn(
          index: 5,
          child: IdleWiggle(
            child: Squishy(
              semanticLabel: 'Play more',
              onTap: () => _backToLevels(context),
              child: Container(
                height: PlayMotion.primaryTouchTarget,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.honey,
                  borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 40,
                      color: AppColors.ink,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Play more',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PopIn(
          index: 6,
          child: Squishy(
            semanticLabel: 'Home',
            onTap: () => _home(context),
            child: Container(
              height: PlayMotion.minTouchTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(PlayMotion.radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 3,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_rounded, size: 28, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Home',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _backToLevels(BuildContext context) {
    final route = args.moduleId == 'video'
        ? RouteNames.videoLearning
        : RouteNames.moduleLevels;
    Navigator.of(context).pushReplacementNamed(route, arguments: args.moduleId);
  }

  void _home(BuildContext context) {
    // Keeps the child selection screen underneath, so the way back out of the
    // modules is still one gesture away.
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.childHome,
      (route) => route.settings.name == RouteNames.childSelection,
    );
  }
}
