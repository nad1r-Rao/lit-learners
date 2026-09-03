import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'play_motion.dart';

/// Makes anything squish when a finger lands on it and spring back when it
/// lifts.
///
/// The most important widget in the child-facing app. At one to four years old
/// the joy is cause and effect — *I touched it and it moved* — and until now
/// nothing in this app reacted to a touch at all. Wrapping a tappable in
/// [Squishy] is what turns a screen from a page into a toy.
///
/// Wrap the widget, do not restyle it:
///
/// ```dart
/// Squishy(
///   onTap: () => open(module),
///   child: ModuleCard(module: module),
/// )
/// ```
///
/// A null [onTap] disables the squish along with the tap, so a disabled
/// control stays honestly inert.
class Squishy extends StatefulWidget {
  const Squishy({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = PlayMotion.pressedScale,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far it compresses. Lower for big surfaces, higher for small ones.
  final double scale;

  /// Fires a light impact on press. Sound is off the table for now, so touch
  /// is the only non-visual confirmation a child gets.
  final bool haptic;

  final String? semanticLabel;

  @override
  State<Squishy> createState() => _SquishyState();
}

class _SquishyState extends State<Squishy> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PlayMotion.pressDown,
    reverseDuration: PlayMotion.springBack,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _press() {
    if (!_enabled) return;
    _controller.forward();
  }

  void _release() {
    if (!_enabled) return;
    // elasticOut on the way back is what makes it read as rubber rather than
    // as a fade. Applied on reverse only, so the press itself stays crisp.
    _controller.reverse();
  }

  void _handleTap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    if (widget.haptic) HapticFeedback.mediumImpact();
    widget.onLongPress!.call();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion keeps the tap and the haptic, drops the movement.
    if (PlayMotion.reduced(context)) {
      return _wrapSemantics(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null ? null : _handleTap,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          child: widget.child,
        ),
      );
    }

    return _wrapSemantics(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap == null ? null : _handleTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.status == AnimationStatus.reverse ||
                    _controller.status == AnimationStatus.dismissed
                ? PlayMotion.springCurve.transform(_controller.value)
                : _controller.value;
            final scale = 1 - (1 - widget.scale) * t.clamp(0.0, 1.4);
            return Transform.scale(scale: scale, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }

  Widget _wrapSemantics(Widget child) {
    if (widget.semanticLabel == null) return child;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(child: child),
    );
  }
}
