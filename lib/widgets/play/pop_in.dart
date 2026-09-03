import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'play_motion.dart';

/// Staggered entrance for anything arriving on screen.
///
/// Generalises the hand-rolled `_AnimatedModuleTile` that already lived in
/// `home_page.dart` — that widget got the idea right, it was just trapped in
/// one file and written as forty lines of controller boilerplate.
///
/// Pass the item's position and the list arrives as a cascade rather than
/// appearing all at once:
///
/// ```dart
/// for (var i = 0; i < modules.length; i++)
///   PopIn(index: i, child: ModuleCard(module: modules[i]))
/// ```
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.index = 0,
    this.slide = true,
  });

  final Widget child;

  /// Position in the list. Later items wait longer, capped by
  /// [PlayMotion.staggerFor] so the tail of a long list is not left blank.
  final int index;

  /// Rise into place as well as scaling up.
  final bool slide;

  @override
  Widget build(BuildContext context) {
    if (PlayMotion.reduced(context)) return child;

    final delay = PlayMotion.staggerFor(index);

    var animation = child
        .animate()
        .fadeIn(delay: delay, duration: PlayMotion.enter)
        .scaleXY(
          begin: 0.82,
          end: 1,
          delay: delay,
          duration: PlayMotion.enter,
          curve: PlayMotion.enterCurve,
        );

    if (slide) {
      animation = animation.slideY(
        begin: 0.14,
        end: 0,
        delay: delay,
        duration: PlayMotion.enter,
        curve: PlayMotion.settleCurve,
      );
    }

    return animation;
  }
}

/// Draws attention to the one thing a child should touch next.
///
/// Deliberately restrained: it waits [after] seconds of stillness, then gives
/// a short wiggle and stops. A permanently wiggling screen tells a toddler
/// nothing, because everything is moving equally — this only fires when a
/// child has gone quiet, and only on the primary target.
class IdleWiggle extends StatefulWidget {
  const IdleWiggle({
    super.key,
    required this.child,
    this.after = const Duration(seconds: 6),
    this.enabled = true,
  });

  final Widget child;
  final Duration after;
  final bool enabled;

  @override
  State<IdleWiggle> createState() => _IdleWiggleState();
}

class _IdleWiggleState extends State<IdleWiggle> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || PlayMotion.reduced(context)) return widget.child;

    return widget.child
        .animate(onPlay: (c) => c.repeat())
        // The long delay before each repeat is the point: wiggle, then rest,
        // rather than a constant jiggle that becomes background noise.
        .shimmer(
          delay: widget.after,
          duration: 900.ms,
          color: Colors.white.withValues(alpha: 0.45),
        )
        .shakeX(delay: widget.after, hz: 3, amount: 2)
        .then(delay: widget.after);
  }
}
