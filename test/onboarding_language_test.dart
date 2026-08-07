import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/onboarding_content.dart';
import 'package:little_learners/models/onboarding.dart';
import 'package:little_learners/repositories/onboarding_repository.dart';
import 'package:little_learners/viewmodels/onboarding_viewmodel.dart';

void main() {
  group('bilingual onboarding content', () {
    test('both languages ship the same number of guide pages', () {
      expect(manualPagesUrdu, hasLength(manualPages.length));
    });

    test('guide pages keep matching icons so the artwork does not shift', () {
      for (var index = 0; index < manualPages.length; index++) {
        expect(manualPagesUrdu[index].iconName, manualPages[index].iconName);
      }
    });

    test('Urdu guide pages are actually written in Urdu', () {
      for (final page in manualPagesUrdu) {
        expect(_hasUrduScript(page.title), isTrue, reason: page.title);
        expect(_hasUrduScript(page.body), isTrue, reason: page.title);
      }
    });

    // The two question sets have to stay aligned: the view model keeps answers
    // keyed by question id across a language switch, so a mismatch here would
    // silently change which answer is correct.
    test('questions line up one to one across languages', () {
      expect(readinessQuestionsUrdu, hasLength(readinessQuestions.length));

      for (var index = 0; index < readinessQuestions.length; index++) {
        final english = readinessQuestions[index];
        final urdu = readinessQuestionsUrdu[index];

        expect(urdu.id, english.id);
        expect(urdu.correctIndex, english.correctIndex);
        expect(urdu.options, hasLength(english.options.length));
      }
    });

    test('Urdu questions, options and tips are written in Urdu', () {
      for (final question in readinessQuestionsUrdu) {
        expect(_hasUrduScript(question.prompt), isTrue, reason: question.id);
        expect(_hasUrduScript(question.tip), isTrue, reason: question.id);
        for (final option in question.options) {
          expect(_hasUrduScript(option), isTrue, reason: option);
        }
      }
    });

    test('question ids are unique within each language', () {
      final englishIds = readinessQuestions.map((q) => q.id).toSet();
      final urduIds = readinessQuestionsUrdu.map((q) => q.id).toSet();

      expect(englishIds, hasLength(readinessQuestions.length));
      expect(urduIds, hasLength(readinessQuestionsUrdu.length));
    });
  });

  group('OnboardingRepository language selection', () {
    test('serves the requested language and defaults to English', () async {
      final repository = InMemoryOnboardingRepository();

      expect(await repository.getManualPages(), manualPages);
      expect(await repository.getReadinessQuestions(), readinessQuestions);
      expect(
        await repository.getManualPages(language: OnboardingLanguage.urdu),
        manualPagesUrdu,
      );
      expect(
        await repository.getReadinessQuestions(
          language: OnboardingLanguage.urdu,
        ),
        readinessQuestionsUrdu,
      );
    });
  });

  group('OnboardingViewModel language', () {
    test('starts in English', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');

      expect(viewModel.language, OnboardingLanguage.english);
      expect(viewModel.manualPages.first.title, manualPages.first.title);
      expect(viewModel.questions.first.prompt, readinessQuestions.first.prompt);
    });

    test('switching to Urdu swaps the guide and the test', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');

      await viewModel.setLanguage(OnboardingLanguage.urdu);

      expect(viewModel.language, OnboardingLanguage.urdu);
      expect(viewModel.manualPages.first.title, manualPagesUrdu.first.title);
      expect(
        viewModel.questions.first.prompt,
        readinessQuestionsUrdu.first.prompt,
      );
    });

    test('answers survive a language switch', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');

      for (final question in viewModel.questions) {
        viewModel.selectAnswer(question.id, question.correctIndex);
      }
      await viewModel.setLanguage(OnboardingLanguage.urdu);

      expect(viewModel.allQuestionsAnswered, isTrue);
      for (final question in viewModel.questions) {
        expect(viewModel.selectedAnswerFor(question.id), question.correctIndex);
      }
    });

    test('a test answered in Urdu is scored the same way', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');
      await viewModel.setLanguage(OnboardingLanguage.urdu);

      for (final question in viewModel.questions) {
        viewModel.selectAnswer(question.id, question.correctIndex);
      }
      final passed = await viewModel.submitReadinessTest('parent-1');

      expect(passed, isTrue);
      expect(viewModel.latestScore, 100);
    });

    test('switching back to English restores the English copy', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');

      await viewModel.setLanguage(OnboardingLanguage.urdu);
      await viewModel.setLanguage(OnboardingLanguage.english);

      expect(viewModel.language, OnboardingLanguage.english);
      expect(viewModel.questions.first.prompt, readinessQuestions.first.prompt);
    });

    test('reloading for a parent keeps the chosen language', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');
      await viewModel.setLanguage(OnboardingLanguage.urdu);

      await viewModel.loadForParent('parent-1');

      expect(viewModel.language, OnboardingLanguage.urdu);
      expect(
        viewModel.questions.first.prompt,
        readinessQuestionsUrdu.first.prompt,
      );
    });

    test('unknown language names fall back to English', () {
      expect(OnboardingLanguage.fromName(null), OnboardingLanguage.english);
      expect(OnboardingLanguage.fromName('klingon'), OnboardingLanguage.english);
      expect(OnboardingLanguage.fromName('urdu'), OnboardingLanguage.urdu);
    });
  });
}

bool _hasUrduScript(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);
