import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/viewmodels/quiz_viewmodel.dart';

void main() {
  group('QuizViewModel.combineWithParentMark', () {
    test('a level with no canvas half keeps its quiz percentage', () {
      expect(
        QuizViewModel.combineWithParentMark(quizPercent: 80),
        80,
      );
    });

    test('a canvas level averages both halves', () {
      expect(
        QuizViewModel.combineWithParentMark(quizPercent: 100, parentMark: 60),
        80,
      );
      expect(
        QuizViewModel.combineWithParentMark(quizPercent: 50, parentMark: 50),
        50,
      );
    });

    test('a perfect quiz cannot overturn a low mark from the parent', () {
      final combined = QuizViewModel.combineWithParentMark(
        quizPercent: 100,
        parentMark: 20,
      );

      expect(combined, 60);
      expect(combined, lessThan(100));
    });

    test('a top mark from the parent cannot hide a failed quiz', () {
      final combined = QuizViewModel.combineWithParentMark(
        quizPercent: 0,
        parentMark: 100,
      );

      expect(combined, 50);
    });

    test('an odd total rounds to the nearest whole mark', () {
      expect(
        QuizViewModel.combineWithParentMark(quizPercent: 70, parentMark: 75),
        73,
      );
    });
  });

  test('QuizViewModel scores correct answers and marks passing result', () {
    const level = LearningLevel(
      id: 'level-1',
      moduleId: 'math',
      stage: 3,
      levelNumber: 1,
      title: 'Demo',
      subtitle: 'Demo',
      type: LevelType.counting,
      passingScore: 70,
      isBundled: true,
      quizQuestions: [
        QuizQuestion(
          id: 'q1',
          prompt: 'First?',
          options: ['No', 'Yes'],
          correctIndex: 1,
        ),
        QuizQuestion(
          id: 'q2',
          prompt: 'Second?',
          options: ['Yes', 'No'],
          correctIndex: 0,
        ),
      ],
    );

    final quiz = QuizViewModel(level);

    quiz.selectAnswer(1);
    quiz.nextQuestion();
    quiz.selectAnswer(0);

    expect(quiz.scorePercent, 100);
    expect(quiz.passed, isTrue);
  });
}
