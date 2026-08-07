import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/trace_score.dart';
import 'package:little_learners/viewmodels/level_activity_viewmodel.dart';

void main() {
  group('LevelActivityViewModel', () {
    test('counting activity completes after target taps', () {
      final viewModel = LevelActivityViewModel(_countingLevel());

      expect(viewModel.targetCount, 3);
      expect(viewModel.currentItemComplete, isFalse);

      viewModel.tapCounter();
      viewModel.tapCounter();

      expect(viewModel.currentItemComplete, isFalse);

      viewModel.tapCounter();

      expect(viewModel.currentItemComplete, isTrue);
      expect(viewModel.isActivityComplete, isFalse);

      viewModel.nextItem();
      viewModel.tapCounter();

      expect(viewModel.isActivityComplete, isTrue);
    });

    test('matching activity completes only on correct option', () {
      final viewModel = LevelActivityViewModel(_matchingLevel());

      viewModel.selectMatch('Triangle');

      expect(viewModel.currentItemComplete, isFalse);

      viewModel.selectMatch('Circle');

      expect(viewModel.currentItemComplete, isTrue);
    });

    test('drawing prompts advance one step at a time', () {
      final viewModel = LevelActivityViewModel(_drawingLevel());

      expect(viewModel.currentItem.title, 'Red Line');
      expect(viewModel.currentItemComplete, isFalse);

      viewModel.nextItem();

      expect(viewModel.currentItem.title, 'Red Line',
          reason: 'an unfinished step must not advance');

      viewModel.markCurrentLearned();
      viewModel.nextItem();

      expect(viewModel.currentItem.title, 'Blue Dot');
      expect(viewModel.currentItemComplete, isFalse);
      expect(viewModel.isLastItem, isTrue);
    });
  });

  group('LevelActivityViewModel tracing', () {
    test('a passing trace completes the card and stores the score', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(_score(82));

      expect(viewModel.currentItemComplete, isTrue);
      expect(viewModel.bestTraceScore, 82);
      expect(viewModel.traceAttempts, 1);
    });

    test('a failing trace keeps the card open and asks for another try', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(_score(30));

      expect(viewModel.currentItemComplete, isFalse);
      expect(viewModel.bestTraceScore, 30);
      expect(viewModel.hasTraceAttemptsLeft, isTrue);
    });

    test('retries only ever improve the stored score', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(_score(64));
      viewModel.recordTraceAttempt(_score(41));

      expect(viewModel.bestTraceScore, 64);
    });

    test('the card unlocks after the attempt limit even when failing', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      for (var attempt = 0;
          attempt < LevelActivityViewModel.maxTraceAttempts;
          attempt++) {
        viewModel.recordTraceAttempt(_score(20));
      }

      expect(viewModel.currentItemComplete, isTrue);
      expect(viewModel.hasTraceAttemptsLeft, isFalse);
      expect(viewModel.bestTraceScore, 20);
    });

    test('checking a blank canvas does not burn an attempt', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(const TraceScore.empty());

      expect(viewModel.traceAttempts, 0);
      expect(viewModel.currentItemComplete, isFalse);
      expect(viewModel.lastTraceScore, isNotNull);
    });

    test('level score averages the best attempt on every card', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(_score(90));
      viewModel.nextItem();
      viewModel.recordTraceAttempt(_score(70));

      expect(viewModel.traceLevelScore, 80);
      expect(viewModel.traceLevelPassed, isTrue);
    });

    test('cards left untraced pull the level score down', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(_score(90));

      // Second card never attempted, so it counts as zero.
      expect(viewModel.traceLevelScore, 45);
      expect(viewModel.traceLevelPassed, isFalse);
    });

    test('restart clears every stored score so a retry starts fresh', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(_score(90));
      viewModel.nextItem();
      viewModel.recordTraceAttempt(_score(88));
      viewModel.restart();

      expect(viewModel.itemIndex, 0);
      expect(viewModel.traceLevelScore, 0);
      expect(viewModel.bestTraceScore, 0);
      expect(viewModel.traceAttempts, 0);
      expect(viewModel.lastTraceScore, isNull);
      expect(viewModel.currentItemComplete, isFalse);
    });

    test('moving to the next card resets the attempt counter', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.recordTraceAttempt(_score(20));
      viewModel.recordTraceAttempt(_score(85));
      viewModel.nextItem();

      expect(viewModel.traceAttempts, 0);
      expect(viewModel.lastTraceScore, isNull);
      expect(viewModel.bestTraceScore, 0);
    });

    test('non-tracing levels ignore trace attempts', () {
      final viewModel = LevelActivityViewModel(_drawingLevel());

      viewModel.recordTraceAttempt(_score(95));

      expect(viewModel.currentItemComplete, isFalse);
      expect(viewModel.traceAttempts, 0);
    });
  });
}

TraceScore _score(int value) {
  return TraceScore(
    coverage: value / 100,
    precision: value / 100,
    score: value,
    hasInk: true,
  );
}

LearningLevel _countingLevel() {
  return const LearningLevel(
    id: 'counting',
    moduleId: 'math',
    stage: 3,
    levelNumber: 1,
    title: 'Counting',
    subtitle: 'Count',
    type: LevelType.counting,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Three',
        prompt: 'Tap three times.',
        displayText: '3',
        visualLabel: 'Three dots',
      ),
      ContentItem(
        title: 'One',
        prompt: 'Tap once.',
        displayText: '1',
        visualLabel: 'One dot',
      ),
    ],
  );
}

LearningLevel _matchingLevel() {
  return const LearningLevel(
    id: 'matching',
    moduleId: 'math',
    stage: 3,
    levelNumber: 2,
    title: 'Matching',
    subtitle: 'Match',
    type: LevelType.matching,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Circle',
        prompt: 'Find circle.',
        displayText: 'O',
        visualLabel: 'Circle',
      ),
      ContentItem(
        title: 'Triangle',
        prompt: 'Find triangle.',
        displayText: '△',
        visualLabel: 'Triangle',
      ),
    ],
  );
}

LearningLevel _drawingLevel() {
  return const LearningLevel(
    id: 'drawing',
    moduleId: 'drawing',
    stage: 1,
    levelNumber: 1,
    title: 'Drawing',
    subtitle: 'Draw',
    type: LevelType.drawing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Red Line',
        prompt: 'Draw a red line.',
        displayText: 'Red',
        visualLabel: 'Red line',
      ),
      ContentItem(
        title: 'Blue Dot',
        prompt: 'Draw a blue dot.',
        displayText: 'Blue',
        visualLabel: 'Blue dot',
      ),
    ],
  );
}

LearningLevel _tracingLevel() {
  return const LearningLevel(
    id: 'tracing',
    moduleId: 'english',
    stage: 3,
    levelNumber: 1,
    title: 'Trace A B',
    subtitle: 'Trace',
    type: LevelType.tracing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter A',
        prompt: 'Trace the letter A.',
        displayText: 'A',
        visualLabel: 'Dotted letter A',
      ),
      ContentItem(
        title: 'Letter B',
        prompt: 'Trace the letter B.',
        displayText: 'B',
        visualLabel: 'Dotted letter B',
      ),
    ],
  );
}
