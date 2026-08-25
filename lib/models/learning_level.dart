import 'content_item.dart';
import 'quiz_question.dart';
import 'video_lesson.dart';

enum LevelType {
  flashcards,
  counting,
  matching,
  story,
  drawing,
  tracing,
  video,
}

class LearningLevel {
  const LearningLevel({
    required this.id,
    required this.moduleId,
    required this.stage,
    required this.levelNumber,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.passingScore,
    required this.isBundled,
    this.portionLabel,
    this.isDownloaded = false,
    this.contentItems = const [],
    this.quizQuestions = const [],
    this.videoLessons = const [],
  });

  final String id;
  final String moduleId;
  final int stage;
  final int levelNumber;
  final String title;
  final String subtitle;
  final LevelType type;
  final int passingScore;
  final bool isBundled;

  /// The slice of the module this level covers, e.g. `A – F` or `1 – 5`.
  ///
  /// Levels are walked in order and their content is walked in order inside
  /// them, so this is what tells a parent where in the alphabet (or the number
  /// line) a level sits. Null for modules that are not a sequence, like Story.
  final String? portionLabel;
  final bool isDownloaded;
  final List<ContentItem> contentItems;
  final List<QuizQuestion> quizQuestions;
  final List<VideoLesson> videoLessons;

  bool get isAvailableOffline => isBundled || isDownloaded;

  LearningLevel copyWith({
    bool? isDownloaded,
  }) {
    return LearningLevel(
      id: id,
      moduleId: moduleId,
      stage: stage,
      levelNumber: levelNumber,
      title: title,
      subtitle: subtitle,
      type: type,
      passingScore: passingScore,
      isBundled: isBundled,
      portionLabel: portionLabel,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      contentItems: contentItems,
      quizQuestions: quizQuestions,
      videoLessons: videoLessons,
    );
  }
}
