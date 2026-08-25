import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/viewmodels/active_child_session.dart';
import 'package:little_learners/viewmodels/learning_viewmodel.dart';
import 'package:little_learners/views/child_dashboard/home_page.dart';
import 'package:little_learners/widgets/module_card.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('the module picker greets the child and lists every module',
      (tester) async {
    final errors = _captureLayoutErrors();
    addTearDown(errors.restore);

    await _pump(tester, await _learning());
    errors.restore();

    expect(find.text('Hi, Ali!'), findsOneWidget);
    expect(find.text('Pick an adventure'), findsOneWidget);
    expect(find.text('2 modules ready'), findsOneWidget);
    expect(find.byType(ModuleCard), findsNWidgets(2));
    expect(errors.details, isEmpty);
  });

  testWidgets('the hero totals the stars and levels already earned',
      (tester) async {
    final errors = _captureLayoutErrors();
    addTearDown(errors.restore);

    await _pump(tester, await _learning(completeFirstLevel: true));
    errors.restore();

    expect(find.text('3'), findsOneWidget); // stars from the finished level
    expect(find.text('stars'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('level done'), findsOneWidget);
    expect(errors.details, isEmpty);
  });

  testWidgets('the grown-up actions are spelled out along the bottom',
      (tester) async {
    final errors = _captureLayoutErrors();
    addTearDown(errors.restore);

    await _pump(tester, await _learning());
    errors.restore();

    expect(find.text('Switch child'), findsOneWidget);
    expect(find.text('Parent dashboard'), findsOneWidget);
    expect(errors.details, isEmpty);
  });

  testWidgets('the hero and the heading stay put while only modules scroll',
      (tester) async {
    await _pump(tester, await _learning());

    // Nothing above the grid sits inside a scroll view any more.
    expect(
      find.ancestor(
        of: find.text('Hi, Ali!'),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Pick an adventure'),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(ModuleCard).first,
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
  });

  testWidgets('module cards fade in and settle as the grid appears',
      (tester) async {
    await _pump(tester, await _learning(), settle: false);

    // Part way through the stagger the cards are still arriving.
    await tester.pump(const Duration(milliseconds: 120));
    expect(_cardOpacity(tester), lessThan(1));

    await tester.pumpAndSettle();
    expect(_cardOpacity(tester), 1);
  });

  testWidgets('without a chosen profile it sends the child back to profiles',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LearningViewModel>.value(
            value: await _learning(),
          ),
          ChangeNotifierProvider<ActiveChildSession>(
            create: (_) => ActiveChildSession(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a learner profile first'), findsOneWidget);
    expect(find.byType(ModuleCard), findsNothing);
  });
}

Future<LearningViewModel> _learning({bool completeFirstLevel = false}) async {
  final progressRepository = InMemoryProgressRepository();
  final learning = LearningViewModel(
    contentRepository: CachedContentRepository(
      contentDao: InMemoryContentDao(),
      bundledModules: const [_englishModule, _mathModule],
      bundledLevels: const [_englishLevel],
      contentRevision: 'test',
    ),
    progressRepository: progressRepository,
  );

  if (completeFirstLevel) {
    await progressRepository.completeLevel(
      childId: 'child-1',
      level: _englishLevel,
      score: 95,
    );
  }

  await learning.loadForProfile(_profile);
  return learning;
}

double _cardOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find
            .ancestor(
              of: find.byType(ModuleCard).first,
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;
}

Future<void> _pump(
  WidgetTester tester,
  LearningViewModel learning, {
  bool settle = true,
}) async {
  // A small phone: the grid is the part most likely to overflow.
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LearningViewModel>.value(value: learning),
        ChangeNotifierProvider<ActiveChildSession>(
          create: (_) => ActiveChildSession()..selectProfile(_profile),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
    ),
  );
  if (settle) await tester.pumpAndSettle();
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

const _englishModule = LearningModule(
  id: 'english',
  title: 'Letters and Sounds',
  description: 'Listen, speak, trace, and discover new words.',
  category: ModuleCategory.english,
  minStage: 1,
  maxStage: 4,
  order: 1,
);

const _mathModule = LearningModule(
  id: 'math',
  title: 'Numbers and Counting',
  description: 'Count, match, and spot the pattern.',
  category: ModuleCategory.math,
  minStage: 1,
  maxStage: 4,
  order: 2,
);

const _englishLevel = LearningLevel(
  id: 'english-stage3-1',
  moduleId: 'english',
  stage: 3,
  levelNumber: 1,
  title: 'Letter A',
  subtitle: 'Meet the letter A.',
  type: LevelType.flashcards,
  passingScore: 70,
  isBundled: true,
);
