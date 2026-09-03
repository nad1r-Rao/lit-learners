import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'play_motion.dart';

/// Soft drifting shapes behind a child screen.
///
/// The app's background is currently a flat `AppColors.cloud` — correct for a
/// settings page, dead for a toddler. This puts slow, low-contrast colour
/// behind the content so the screen feels alive without anything competing
/// with the thing a child is meant to touch.
///
/// Deliberately low opacity and very slow. It should never be the first thing
/// noticed.
class FloatingBlobs extends StatefulWidget {
  const FloatingBlobs({
    super.key,
    required this.child,
    this.accent,
    this.blobs = 5,
  });

  final Widget child;

  /// Tints the drift toward a module's colour world.
  final Color? accent;

  final int blobs;

  @override
  State<FloatingBlobs> createState() => _FloatingBlobsState();
}

class _FloatingBlobsState extends State<FloatingBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
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

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        if (!PlayMotion.reduced(context))
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _BlobPainter(
                  t: _controller.value,
                  count: widget.blobs,
                  palette: palette,
                ),
                size: Size.infinite,
              ),
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
