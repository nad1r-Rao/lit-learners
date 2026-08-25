import 'package:flutter/widgets.dart';

import '../../models/onboarding.dart';
import '../utils/learning_text_direction.dart';

/// Presentation rules for the two onboarding languages.
extension OnboardingLanguagePresentation on OnboardingLanguage {
  TextDirection get textDirection => switch (this) {
        OnboardingLanguage.english => TextDirection.ltr,
        OnboardingLanguage.urdu => TextDirection.rtl,
      };

  String? get fontFamily => switch (this) {
        OnboardingLanguage.english => null,
        OnboardingLanguage.urdu => LearningTextDirection.urduFontFamily,
      };

  /// Shown in the picker in the language's own script, so a parent who cannot
  /// read the other option can still find theirs.
  String get nativeLabel => switch (this) {
        OnboardingLanguage.english => 'English',
        OnboardingLanguage.urdu => 'اردو',
      };

  /// The same name written in the other language, as a subtitle.
  String get englishLabel => switch (this) {
        OnboardingLanguage.english => 'English',
        OnboardingLanguage.urdu => 'Urdu',
      };

  TextAlign get textAlign => LearningTextDirection.alignFor(textDirection);

  /// Nastaliq glyphs are tall and cascade down to the left, so Urdu needs more
  /// leading than Latin text before lines start colliding.
  double get bodyLineHeight => switch (this) {
        OnboardingLanguage.english => 1.35,
        OnboardingLanguage.urdu => 1.9,
      };

  TextStyle? styleFor(TextStyle? base) {
    final family = fontFamily;
    if (family == null) return base;
    return (base ?? const TextStyle()).copyWith(fontFamily: family);
  }
}

/// Parent-facing copy for the onboarding flow, in both languages.
///
/// The app has no `intl` setup and every other screen carries its strings
/// inline, so this keeps the same shape rather than pulling in a full
/// localisation toolchain for one flow.
class OnboardingStrings {
  const OnboardingStrings._({
    required this.manualTitle,
    required this.welcomeBack,
    required this.guideProgress,
    required this.next,
    required this.startReadinessTest,
    required this.changeLanguage,
    required this.languageTitle,
    required this.languageHeading,
    required this.languageSubtitle,
    required this.languageNote,
    required this.continueLabel,
    required this.testTitle,
    required this.passingBanner,
    required this.scoreLabel,
    required this.reviewTips,
    required this.retakeTest,
    required this.submitTest,
    required this.tryAgainMessage,
    required this.notSignedIn,
    required this.readingIn,
  });

  static const _english = OnboardingStrings._(
    manualTitle: 'Parent Manual',
    welcomeBack: 'Welcome back',
    guideProgress: 'Guide {current} of {total}',
    next: 'Next',
    startReadinessTest: 'Start readiness test',
    changeLanguage: 'Change language',
    languageTitle: 'Choose Language',
    languageHeading: 'Which language should the readiness test use?',
    languageSubtitle:
        'Pick the language you read most comfortably. The questions, tips and '
        'buttons all switch to your choice.',
    languageNote: 'You can come back and change this before you start.',
    continueLabel: 'Continue',
    testTitle: 'Readiness Test',
    passingBanner: 'Score {score}% or more to continue.',
    scoreLabel: 'Score: {score}%',
    reviewTips: 'Review these tips, then try again.',
    retakeTest: 'Retake test',
    submitTest: 'Submit test',
    tryAgainMessage: 'Readiness score needs another try.',
    notSignedIn: 'Parent not signed in.',
    readingIn: 'Reading in',
  );

  static const _urdu = OnboardingStrings._(
    manualTitle: 'والدین کی رہنما کتاب',
    welcomeBack: 'خوش آمدید',
    guideProgress: 'رہنمائی {current} از {total}',
    next: 'اگلا',
    startReadinessTest: 'تیاری کا امتحان شروع کریں',
    changeLanguage: 'زبان تبدیل کریں',
    languageTitle: 'زبان منتخب کریں',
    languageHeading: 'تیاری کا امتحان کس زبان میں ہو؟',
    languageSubtitle:
        'وہ زبان چنیں جو آپ آسانی سے پڑھ سکتے ہیں۔ سوالات، مشورے اور بٹن سب '
        'آپ کی پسند کے مطابق بدل جائیں گے۔',
    languageNote: 'امتحان شروع کرنے سے پہلے آپ اسے دوبارہ بدل سکتے ہیں۔',
    continueLabel: 'جاری رکھیں',
    testTitle: 'تیاری کا امتحان',
    passingBanner: 'آگے بڑھنے کے لیے {score}% یا زیادہ نمبر حاصل کریں۔',
    scoreLabel: 'نمبر: {score}%',
    reviewTips: 'یہ مشورے پڑھیں، پھر دوبارہ کوشش کریں۔',
    retakeTest: 'دوبارہ امتحان دیں',
    submitTest: 'امتحان جمع کرائیں',
    tryAgainMessage: 'تیاری کے نمبر کم ہیں، ایک بار پھر کوشش کریں۔',
    notSignedIn: 'والدین سائن اِن نہیں ہیں۔',
    readingIn: 'پڑھنے کی زبان',
  );

  static OnboardingStrings of(OnboardingLanguage language) {
    return switch (language) {
      OnboardingLanguage.english => _english,
      OnboardingLanguage.urdu => _urdu,
    };
  }

  final String manualTitle;
  final String welcomeBack;
  final String guideProgress;
  final String next;
  final String startReadinessTest;
  final String changeLanguage;
  final String languageTitle;
  final String languageHeading;
  final String languageSubtitle;
  final String languageNote;
  final String continueLabel;
  final String testTitle;
  final String passingBanner;
  final String scoreLabel;
  final String reviewTips;
  final String retakeTest;
  final String submitTest;
  final String tryAgainMessage;
  final String notSignedIn;
  final String readingIn;

  String guideProgressFor(int current, int total) {
    return guideProgress
        .replaceAll('{current}', '$current')
        .replaceAll('{total}', '$total');
  }

  String passingBannerFor(int score) {
    return passingBanner.replaceAll('{score}', '$score');
  }

  String scoreLabelFor(int score) {
    return scoreLabel.replaceAll('{score}', '$score');
  }
}
