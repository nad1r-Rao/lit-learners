import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'play_motion.dart';

/// Soft colour behind a child screen.
///
/// The app's background is a flat `AppColors.cloud` — correct for a settings
/// page, dead for a toddler. This puts a tinted gradient and low-contrast
/// blobs behind the content so the screen has depth and warmth.
///
/// **[drift] is off by default, deliberately.** A background that animates
/// forever repaints on every frame for the whole life of a screen, which is a
/// real cost on the budget Android hardware this ships to, and it earns very
/// little: what makes the screen feel playful is the colour and the things
/// that respond to a touch, not scenery that moves on its own. It also makes
/// `pumpAndSettle` hang, so every widget test on a drifting screen times out.
///
/// Turn it on for a screen that is otherwise still and wants ambience. Do not
/// turn it on everywhere.
class FloatingBlobs extends StatefulWidget {
  const FloatingBlobs({
    super.key,
    required this.child,
    this.accent,
    this.blobs = 5,
    this.drift = false,
  });

  final Widget child;

  /// Tints the background toward a module's colour world.
  final Color? accent;

  final int blobs;

  /// Slowly move the blobs. See the note above before enabling.
  final bool drift;

  @override
  State<FloatingBlobs> createState() => _FloatingBlobsState();
}

class _FloatingBlobsState extends State<FloatingBlobs>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.drift) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 26),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? AppColors.violet;
    final palette = [
      accent,
      AppColors.honey,
      AppColors.rose,
      AppColors.aqua,
      AppColors.lime,
    ];

    final background = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.10), AppColors.cloud),
            AppColors.cloud,
          ],
        ),
      ),
    );

    final controller = _controller;
    final animate = controller != null && !PlayMotion.reduced(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        RepaintBoundary(
          child: animate
              ? AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => CustomPaint(
                    painter: _BlobPainter(
                      t: controller.value,
                      count: widget.blobs,
                      palette: palette,
                    ),
                    size: Size.infinite,
                  ),
                )
              : CustomPaint(
                  painter: _BlobPainter(
                    t: 0,
                    count: widget.blobs,
                    palette: palette,
                  ),
                  size: Size.infinite,
                ),
        ),
        widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({
    required this.t,
    required this.count,
    required this.palette,
  });

  final double t;
  final int count;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final seed = i / count;
      final phase = (t + seed) % 1.0;
      final angle = phase * math.pi * 2;

      final cx = size.width * (0.15 + 0.7 * seed) + math.cos(angle) * 26;
      final cy = size.height * (0.12 + 0.76 * ((seed * 1.7) % 1.0)) +
          math.sin(angle) * 34;
      final radius = size.shortestSide * (0.16 + 0.09 * ((seed * 2.3) % 1.0));

      paint.color = palette[i % palette.length].withValues(alpha: 0.09);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.t != t;
}
