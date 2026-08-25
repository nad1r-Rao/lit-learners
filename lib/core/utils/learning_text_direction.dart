import 'package:flutter/widgets.dart';

import '../../models/learning_level.dart';
import '../../models/learning_module.dart';

class LearningTextDirection {
  const LearningTextDirection._();

  static const urduFontFamily = 'NotoNastaliqUrdu';

  static TextDirection forModule(LearningModule module) {
    return module.category == ModuleCategory.urdu
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  /// Urdu content is not confined to the Urdu module — the tracing module
  /// teaches Urdu letters too — so the level's own text decides the direction
  /// when the module id does not.
  static TextDirection forLevel(LearningLevel level) {
    if (level.moduleId == 'urdu') return TextDirection.rtl;
    if (_hasArabicScript(level.title) || _hasArabicScript(level.subtitle)) {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }

  static TextDirection forText(String text) {
    return _hasArabicScript(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  static TextAlign alignFor(TextDirection direction) {
    return direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
  }

  static String? fontFamilyFor(TextDirection direction) {
    return direction == TextDirection.rtl ? urduFontFamily : null;
  }

  static String? fontFamilyForText(String text) {
    return fontFamilyFor(forText(text));
  }

  static TextStyle? styleFor(TextStyle? baseStyle, TextDirection direction) {
    final fontFamily = fontFamilyFor(direction);
    if (fontFamily == null) return baseStyle;

    return (baseStyle ?? const TextStyle()).copyWith(
      fontFamily: fontFamily,
    );
  }

  static TextStyle? styleForText(TextStyle? baseStyle, String text) {
    return styleFor(baseStyle, forText(text));
  }

  static bool _hasArabicScript(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }
}
