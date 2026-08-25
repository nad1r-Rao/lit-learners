import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/learning_text_direction.dart';
import '../core/utils/module_visuals.dart';
import '../models/learning_module.dart';

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    required this.module,
    required this.onTap,
    super.key,
  });

  final LearningModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ModuleVisuals.colorFor(module.category);
    final textDirection = LearningTextDirection.forModule(module);
    final titleStyle = LearningTextDirection.styleFor(
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
      textDirection,
    );
    final bodyStyle = LearningTextDirection.styleFor(
      Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.ink.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
      textDirection,
    );

    return Semantics(
      button: true,
      label: 'Open ${module.title}',
      child: Material(
        color: AppColors.panel,
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        shadowColor: color.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withValues(alpha: 0.22), width: 1.4),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A soft wash of the module colour from the top, so the eight
              // cards read as a set of siblings rather than eight logos.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.20),
                      color.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -22,
                top: -26,
                child: _DecorativeDot(
                  color: color.withValues(alpha: 0.16),
                  size: 76,
                ),
              ),
              Positioned(
                left: -14,
                bottom: -18,
                child: _DecorativeDot(
                  color: AppColors.honey.withValues(alpha: 0.22),
                  size: 46,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: textDirection == TextDirection.rtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ModuleIconTile(color: color, module: module),
                          const Spacer(),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.86),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: color,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: textDirection,
                      child: Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            LearningTextDirection.alignFor(textDirection),
                        style: titleStyle,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Directionality(
                      textDirection: textDirection,
                      child: Text(
                        module.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            LearningTextDirection.alignFor(textDirection),
                        style: bodyStyle,
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

class _ModuleIconTile extends StatelessWidget {
  const _ModuleIconTile({required this.color, required this.module});

  final Color color;
  final LearningModule module;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.28), color),
            color,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.36),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        ModuleVisuals.iconFor(module.category),
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _DecorativeDot extends StatelessWidget {
  const _DecorativeDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
