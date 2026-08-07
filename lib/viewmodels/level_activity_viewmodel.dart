import 'package:flutter/foundation.dart';

import '../models/content_item.dart';
import '../models/learning_level.dart';

class LevelActivityViewModel extends ChangeNotifier {
  LevelActivityViewModel(this.level);

  final LearningLevel level;
  int _itemIndex = 0;
  int _tapCount = 0;
  String? _selectedMatch;
  bool _currentItemComplete = false;
  int _attempt = 0;

  int get itemIndex => _itemIndex;

  /// Bumped by [restart]. Canvas activities watch it so they know to wipe the
  /// page when a parent sends the level back for more practice, which the item
  /// index alone cannot tell them on a single-card level.
  int get attempt => _attempt;
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

  /// Sends the level back to its first card so it can be worked through again,
  /// used when a parent marks canvas work as needing more practice.
  void restart() {
    _attempt += 1;
    _itemIndex = 0;
    _resetItemState();
    notifyListeners();
  }

  void _resetItemState() {
    _tapCount = 0;
    _selectedMatch = null;
    _currentItemComplete = false;
  }
}
