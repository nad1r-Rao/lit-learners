import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/routing/route_names.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/repositories/child_profile_repository.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/viewmodels/active_child_session.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';
import 'package:little_learners/viewmodels/learning_viewmodel.dart';
import 'package:little_learners/viewmodels/profile_viewmodel.dart';
import 'package:little_learners/views/profile/child_selection_page.dart';
import 'package:little_learners/widgets/child_avatar.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('the selection screen shows each learner as a face and a name',
      (tester) async {
    final harness = await _Harness.create(names: const ['Ali', 'Sara']);

    await harness.pump(tester);

    expect(find.text('Who is learning today?'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    // One per learner, plus the koala in the header is an image, not an avatar.
    expect(find.byType(ChildAvatar), findsNWidgets(2));
    // None of the parent dashboard comes along for the ride.
    expect(find.text('Parent Dashboard'), findsNothing);
    expect(find.text('Start learning'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('tapping a learner makes them active and opens their modules',
      (tester) async {
    final harness = await _Harness.create(names: const ['Ali', 'Sara']);

    await harness.pump(tester);
    await tester.tap(find.text('Sara'));
    await tester.pumpAndSettle();

    expect(harness.session.activeChild?.name, 'Sara');
    expect(harness.routeLog.pushed, contains(RouteNames.childHome));
  });

  testWidgets('the parent dashboard sits behind the parental check',
      (tester) async {
    final harness = await _Harness.create(names: const ['Ali']);

    await harness.pump(tester);
    await tester.tap(find.byTooltip('Parent dashboard'));
    await tester.pumpAndSettle();

    expect(harness.routeLog.pushed, contains(RouteNames.parentalLock));
    expect(harness.routeLog.pushed, isNot(contains(RouteNames.parentDashboard)));
  });

  testWidgets('with no learners yet it offers to add one', (tester) async {
    final harness = await _Harness.create(names: const []);

    await harness.pump(tester);

    expect(find.text('No learners yet'), findsOneWidget);
    expect(find.text('Add a learner'), findsOneWidget);
  });
}

class _Harness {
  _Harness({
    required this.auth,
    required this.profiles,
    required this.session,
    required this.learning,
  });

  static Future<_Harness> create({required List<String> names}) async {
    final authRepository = InMemoryAuthRepository();
    final parent = await authRepository.signUp(
      email: 'parent@example.com',
      password: 'StrongPass1!',
    );
    final auth = AuthViewModel(authRepository);
    await auth.loadCurrentParent();

    final profileRepository = InMemoryChildProfileRepository();
    for (final name in names) {
      await profileRepository.createProfile(
        parentId: parent.id,
        name: name,
        age: 4,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: false,
        displayPreference: 'firstName',
      );
    }

    return _Harness(
      auth: auth,
      profiles: ProfileViewModel(profileRepository),
      session: ActiveChildSession(),
      learning: LearningViewModel(
        contentRepository: CachedContentRepository(
          contentDao: InMemoryContentDao(),
          bundledModules: const [],
          bundledLevels: const [],
          contentRevision: 'test',
        ),
        progressRepository: InMemoryProgressRepository(),
      ),
    );
  }

  final AuthViewModel auth;
  final ProfileViewModel profiles;
  final ActiveChildSession session;
  final LearningViewModel learning;
  final routeLog = _RouteLog();

  Future<void> pump(WidgetTester tester) async {
    // A small phone: the learner grid is the part most likely to overflow.
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ChangeNotifierProvider<ProfileViewModel>.value(value: profiles),
          ChangeNotifierProvider<ActiveChildSession>.value(value: session),
          ChangeNotifierProvider<LearningViewModel>.value(value: learning),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          navigatorObservers: [routeLog],
          home: const ChildSelectionPage(),
          // Every route this screen leads to is stubbed: the assertions are
          // about where it sends the child, not about what lands there.
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _RouteLog extends NavigatorObserver {
  final pushed = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}
