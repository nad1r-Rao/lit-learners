import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/viewmodels/active_child_session.dart';
import 'package:little_learners/viewmodels/learning_viewmodel.dart';
import 'package:little_learners/views/child_dashboard/module_levels_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('the levels screen names the portion each level covers',
      (tester) async {
    final errors = _captureLayoutErrors();
    addTearDown(errors.restore);

    await _pump(tester);
    errors.restore();

    // The ladder a child climbs, visible without opening anything.
    expect(find.text('Letters A – F'), findsOneWidget);
    expect(find.text('Letters G – L'), findsOneWidget);
    expect(find.text('Letters M – R'), findsOneWidget);
    expect(find.text('Letters S – Z'), findsOneWidget);
    expect(errors.details, isEmpty);
  });

  testWidgets('the portion chip counts the steps inside the level',
      (tester) async {
    await _pump(tester);

    // A – F is six letters, walked one at a time.
    expect(find.textContaining('A – F  ·  6 steps'), findsOneWidget);
    expect(find.textContaining('S – Z  ·  8 steps'), findsOneWidget);
  });

  testWidgets('only the first level is open until it is finished',
      (tester) async {
    await _pump(tester);

    // Level 1 is open; the other three portions are covered by a lock whose
    // tooltip says why.
    expect(find.byIcon(Icons.lock), findsNWidgets(3));
    expect(
      find.byTooltip('Finish the previous level first.'),
      findsNWidgets(3),
    );
  });
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final learning = LearningViewModel(
    contentRepository: CachedContentRepository(
      contentDao: InMemoryContentDao(),
    ),
    progressRepository: InMemoryProgressRepository(),
  );
  await learning.loadForProfile(_profile);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LearningViewModel>.value(value: learning),
        ChangeNotifierProvider<ActiveChildSession>(
          create: (_) => ActiveChildSession()..selectProfile(_profile),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ModuleLevelsPage(moduleId: 'english'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

_LayoutErrorCapture _captureLayoutErrors() {
  final capture = _LayoutErrorCapture(FlutterError.onError);
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) {
      capture.details.add(details);
    } else {
      capture.original?.call(details);
    }
  };
  return capture;
}

class _LayoutErrorCapture {
  _LayoutErrorCapture(this.original);

  final void Function(FlutterErrorDetails)? original;
  final details = <FlutterErrorDetails>[];
  bool _restored = false;

  void restore() {
    if (_restored) return;
    FlutterError.onError = original;
    _restored = true;
  }
}

final _profile = ChildProfile(
  id: 'child-1',
  parentId: 'parent-1',
  name: 'Ali',
  age: 3,
  avatarAsset: 'koala-blue',
  leaderboardOptIn: false,
  displayPreference: 'firstName',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isSynced: true,
);
