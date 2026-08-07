import 'package:flutter/foundation.dart';

import '../models/onboarding.dart';
import '../repositories/onboarding_repository.dart';

class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel(this._onboardingRepository);

  static const passingScore = 70;

  final OnboardingRepository _onboardingRepository;

  ParentOnboardingState? _state;
  List<ManualPageContent> _manualPages = const [];
  List<ReadinessQuestion> _questions = const [];
  final Map<String, int> _selectedAnswers = {};
  OnboardingLanguage _language = OnboardingLanguage.english;
  bool _isLoading = false;
  int? _latestScore;
  bool? _latestPassed;

  ParentOnboardingState? get state => _state;
  List<ManualPageContent> get manualPages => List.unmodifiable(_manualPages);
  List<ReadinessQuestion> get questions => List.unmodifiable(_questions);
  OnboardingLanguage get language => _language;
  bool get isLoading => _isLoading;
  int get currentManualPage => _state?.lastManualPageIndex ?? 0;
  int? get latestScore => _latestScore;
  bool? get latestPassed => _latestPassed;
  bool get manualCompleted => _state?.manualCompleted ?? false;
  bool get testPassed => _state?.testPassed ?? false;
  bool get allQuestionsAnswered => _selectedAnswers.length == _questions.length;

  int? selectedAnswerFor(String questionId) => _selectedAnswers[questionId];

  Future<void> loadForParent(String parentId) async {
    _isLoading = true;
    notifyListeners();

    await _loadContent();
    _state = await _onboardingRepository.getState(parentId);

    _isLoading = false;
    notifyListeners();
  }

  /// Swaps the guide and the readiness test into [value].
  ///
  /// Answers already given are kept: both languages use the same question ids
  /// and the same option order, so a parent who switches part-way through does
  /// not start over and no answer changes from right to wrong.
  Future<void> setLanguage(OnboardingLanguage value) async {
    if (_language == value) return;

    _language = value;
    await _loadContent();
    notifyListeners();
  }

  Future<void> _loadContent() async {
    _manualPages = await _onboardingRepository.getManualPages(
      language: _language,
    );
    _questions = await _onboardingRepository.getReadinessQuestions(
      language: _language,
    );
  }

  Future<void> saveManualPage(String parentId, int pageIndex) async {
    _state = await _onboardingRepository.saveManualPage(
      parentId: parentId,
      pageIndex: pageIndex,
    );
    notifyListeners();
  }

  Future<void> completeManual(String parentId) async {
    _state = await _onboardingRepository.completeManual(parentId);
    notifyListeners();
  }

  void selectAnswer(String questionId, int answerIndex) {
    _selectedAnswers[questionId] = answerIndex;
    notifyListeners();
  }

  Future<bool> submitReadinessTest(String parentId) async {
    if (!allQuestionsAnswered) return false;

    var correct = 0;
    for (final question in _questions) {
      final selectedIndex = _selectedAnswers[question.id];
      if (selectedIndex != null && question.isCorrect(selectedIndex)) {
        correct += 1;
      }
    }

    final score = ((correct / _questions.length) * 100).round();
    final passed = score >= passingScore;
    _latestScore = score;
    _latestPassed = passed;
    _state = await _onboardingRepository.saveReadinessResult(
      parentId: parentId,
      score: score,
      passed: passed,
    );
    notifyListeners();
    return passed;
  }

  void resetReadinessAttempt() {
    _selectedAnswers.clear();
    _latestScore = null;
    _latestPassed = null;
    notifyListeners();
  }
}
