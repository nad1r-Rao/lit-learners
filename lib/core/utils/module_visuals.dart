import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../models/learning_module.dart';

class ModuleVisuals {
  const ModuleVisuals._();

  /// Module ids mirror the category names, so a level can find its accent
  /// colour without loading the whole module record.
  static ModuleCategory categoryForModuleId(String moduleId) {
    for (final category in ModuleCategory.values) {
      if (category.name == moduleId) return category;
    }
    return ModuleCategory.english;
  }

  static Color colorForModuleId(String moduleId) {
    return colorFor(categoryForModuleId(moduleId));
  }

  static IconData iconFor(ModuleCategory category) {
    return switch (category) {
      ModuleCategory.english => Icons.abc,
      ModuleCategory.math => Icons.functions,
      ModuleCategory.urdu => Icons.translate,
      ModuleCategory.logic => Icons.extension,
      ModuleCategory.story => Icons.auto_stories,
      ModuleCategory.drawing => Icons.brush,
      ModuleCategory.tracing => Icons.gesture,
      ModuleCategory.video => Icons.play_circle,
    };
  }

  static Color colorFor(ModuleCategory category) {
    return switch (category) {
      ModuleCategory.english => AppColors.sky,
      ModuleCategory.math => AppColors.leaf,
      ModuleCategory.urdu => AppColors.plum,
      ModuleCategory.logic => AppColors.honey,
      ModuleCategory.story => AppColors.coral,
      ModuleCategory.drawing => const Color(0xFF3B8C8C),
      ModuleCategory.tracing => AppColors.aqua,
      ModuleCategory.video => const Color(0xFFCF4D8F),
    };
  }
}
