import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
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

  group('LevelActivityViewModel canvas levels', () {
    // Nothing in the app grades a traced letter any more: the child says when a
    // page is done and a parent marks the level at the end.
    test('a tracing card is finished by the child, one letter at a time', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      expect(viewModel.currentItem.title, 'Letter A');
      expect(viewModel.currentItemComplete, isFalse);

      viewModel.markCurrentLearned();

      expect(viewModel.currentItemComplete, isTrue);
      expect(viewModel.isActivityComplete, isFalse);

      viewModel.nextItem();

      expect(viewModel.currentItem.title, 'Letter B');
      expect(viewModel.currentItemComplete, isFalse);

      viewModel.markCurrentLearned();

      expect(viewModel.isActivityComplete, isTrue);
    });

    test('restart sends the level back to its first card', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());

      viewModel.markCurrentLearned();
      viewModel.nextItem();
      viewModel.markCurrentLearned();
      viewModel.restart();

      expect(viewModel.itemIndex, 0);
      expect(viewModel.currentItemComplete, isFalse);
      expect(viewModel.isActivityComplete, isFalse);
    });

    // The canvas views watch this, because on a one-card level the item index
    // is already zero and cannot tell them the page should be wiped.
    test('restart bumps the attempt counter even from the first card', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());
      final attempt = viewModel.attempt;

      viewModel.markCurrentLearned();
      viewModel.restart();

      expect(viewModel.attempt, attempt + 1);
    });

    test('moving between cards leaves the attempt counter alone', () {
      final viewModel = LevelActivityViewModel(_tracingLevel());
      final attempt = viewModel.attempt;

      viewModel.markCurrentLearned();
      viewModel.nextItem();

      expect(viewModel.attempt, attempt);
    });
  });
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
