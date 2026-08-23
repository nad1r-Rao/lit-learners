import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/routing/app_router.dart';
import 'package:little_learners/core/routing/auth_flow_router.dart';
import 'package:little_learners/core/routing/route_names.dart';
import 'package:little_learners/models/parent_account.dart';
import 'package:little_learners/repositories/child_profile_repository.dart';
import 'package:little_learners/repositories/onboarding_repository.dart';
import 'package:little_learners/viewmodels/onboarding_viewmodel.dart';
import 'package:little_learners/viewmodels/profile_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a returning parent with a learner lands on child selection',
      (tester) async {
    final harness = await _Harness.create(
      onboardingDone: true,
      childNames: const ['Ali'],
    );

    await harness.routeAfterAuth(tester);

    expect(harness.currentRoute, RouteNames.childSelection);
    // The parent dashboard is opened on purpose, never on the way in.
    expect(harness.pushed, isNot(contains(RouteNames.parentDashboard)));
  });

  testWidgets('a brand new parent is sent to create the first profile',
      (tester) async {
    final harness = await _Harness.create(
      onboardingDone: true,
      childNames: const [],
    );

    await harness.routeAfterAuth(tester);

    expect(harness.currentRoute, RouteNames.profileEdit);
    final args = harness.currentArguments as ProfileEditArgs;
    expect(args.profileId, isNull);
    // Saving that first profile has to land on the child selection screen.
    expect(args.returnRoute, RouteNames.childSelection);
  });

  testWidgets('unfinished onboarding still comes before any of this',
      (tester) async {
    final harness = await _Harness.create(
      onboardingDone: false,
      childNames: const ['Ali'],
    );

    await harness.routeAfterAuth(tester);

    expect(harness.currentRoute, RouteNames.onboardingManual);
  });
}

class _Harness {
  _Harness({required this.onboarding, required this.profiles});

  static Future<_Harness> create({
    required bool onboardingDone,
    required List<String> childNames,
  }) async {
    final onboardingRepository = InMemoryOnboardingRepository();
    if (onboardingDone) {
      await onboardingRepository.completeManual(_parent.id);
      await onboardingRepository.saveReadinessResult(
        parentId: _parent.id,
        score: 100,
        passed: true,
      );
    }

    final profileRepository = InMemoryChildProfileRepository();
    for (final name in childNames) {
      await profileRepository.createProfile(
        parentId: _parent.id,
        name: name,
        age: 4,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: false,
        displayPreference: 'firstName',
      );
    }

    return _Harness(
      onboarding: OnboardingViewModel(onboardingRepository),
      profiles: ProfileViewModel(profileRepository),
    );
  }

  final OnboardingViewModel onboarding;
  final ProfileViewModel profiles;
  final pushed = <String?>[];
  RouteSettings? _current;

  String? get currentRoute => _current?.name;
  Object? get currentArguments => _current?.arguments;

  Future<void> routeAfterAuth(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OnboardingViewModel>.value(value: onboarding),
          ChangeNotifierProvider<ProfileViewModel>.value(value: profiles),
        ],
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name != RouteNames.splash) {
              pushed.add(settings.name);
              _current = settings;
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => _StartButton(
                onPressed: () => AuthFlowRouter.routeAfterAuth(
                  context: context,
                  parent: _parent,
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(onPressed: onPressed, child: const Text('go')),
      ),
    );
  }
}

final _parent = ParentAccount(
  id: 'parent-1',
  email: 'parent@example.com',
  createdAt: DateTime(2026),
);
