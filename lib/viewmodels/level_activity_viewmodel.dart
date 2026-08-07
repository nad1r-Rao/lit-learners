import 'package:flutter/foundation.dart';

import '../models/content_item.dart';
import '../models/learning_level.dart';
import '../models/trace_score.dart';

class LevelActivityViewModel extends ChangeNotifier {
  LevelActivityViewModel(this.level);

  /// A tracing card unlocks after this many tries even if the child never
  /// reaches the passing mark, so nobody is stuck on one letter. The best
  /// attempt is what counts, so the level score still reflects real work.
  static const maxTraceAttempts = 3;

  final LearningLevel level;
  int _itemIndex = 0;
  int _tapCount = 0;
  String? _selectedMatch;
  bool _currentItemComplete = false;

  /// Best mark per card index, so a retry can only ever help.
  final Map<int, int> _traceScores = <int, int>{};
  int _traceAttempts = 0;
  TraceScore? _lastTraceScore;

  int get itemIndex => _itemIndex;
  ContentItem get currentItem => level.contentItems[_itemIndex];
  bool get currentItemComplete => _currentItemComplete;
  int get tapCount => _tapCount;
  bool get isLastItem => _itemIndex == level.contentItems.length - 1;
  bool get isActivityComplete => _currentItemComplete && isLastItem;

  int get targetCount {
    return int.tryParse(currentItem.displayText) ?? 1;
  }

  String? get selectedMatch => _selectedMatch;

  List<String> get matchOptions {
    final labels =
        level.contentItems.map((item) => item.title).toSet().toList();
    if (!labels.contains(currentItem.title)) {
      labels.insert(0, currentItem.title);
    }
    return labels;
  }

  // --- Tracing -------------------------------------------------------------

  /// Result of the most recent check, or null while the child is still drawing.
  TraceScore? get lastTraceScore => _lastTraceScore;
  int get traceAttempts => _traceAttempts;
  int get bestTraceScore => _traceScores[_itemIndex] ?? 0;
  bool get hasTraceAttemptsLeft => _traceAttempts < maxTraceAttempts;

  /// Average of the best attempt on every card, on the same 0-100 scale as a
  /// quiz score so it flows through the existing stars and leaderboard rules.
  int get traceLevelScore {
    if (level.contentItems.isEmpty) return 0;

    var total = 0;
    for (var index = 0; index < level.contentItems.length; index++) {
      total += _traceScores[index] ?? 0;
    }
    return (total / level.contentItems.length).round();
  }

  bool get traceLevelPassed => traceLevelScore >= level.passingScore;

  void recordTraceAttempt(TraceScore score) {
    if (level.type != LevelType.tracing) return;

    _lastTraceScore = score;
    if (!score.hasInk) {
      // An empty canvas is a prompt to try, not a failed attempt.
      notifyListeners();
      return;
    }

    _traceAttempts += 1;
    if (score.score > bestTraceScore) {
      _traceScores[_itemIndex] = score.score;
    }
    if (score.passed(level.passingScore) || !hasTraceAttemptsLeft) {
      _currentItemComplete = true;
    }
    notifyListeners();
  }

  /// Called when the child starts drawing again so stale feedback disappears.
  void clearTraceFeedback() {
    if (_lastTraceScore == null) return;

    _lastTraceScore = null;
    notifyListeners();
  }

  // --- Other activity types ------------------------------------------------

  void tapCounter() {
    if (level.type != LevelType.counting || _currentItemComplete) return;

    _tapCount += 1;
    if (_tapCount >= targetCount) {
      _currentItemComplete = true;
    }
    notifyListeners();
  }

  void selectMatch(String value) {
    if (level.type != LevelType.matching || _currentItemComplete) return;

    _selectedMatch = value;
    _currentItemComplete = value == currentItem.title;
    notifyListeners();
  }

  void markCurrentLearned() {
    _currentItemComplete = true;
    notifyListeners();
  }

  void nextItem() {
    if (!_currentItemComplete || isLastItem) return;

    _itemIndex += 1;
    _resetItemState();
    notifyListeners();
  }

  void resetCurrentItem() {
    _resetItemState();
    notifyListeners();
  }

  /// Clears every card's marks so a level can be retried from the start after
  /// missing the passing score.
  void restart() {
    _itemIndex = 0;
    _traceScores.clear();
    _resetItemState();
    notifyListeners();
  }

  void _resetItemState() {
    _tapCount = 0;
    _selectedMatch = null;
    _currentItemComplete = false;
    _traceAttempts = 0;
    _lastTraceScore = null;
  }
}
