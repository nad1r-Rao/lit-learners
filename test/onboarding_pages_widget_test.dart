import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/routing/route_names.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/data/onboarding_content.dart';
import 'package:little_learners/models/onboarding.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/repositories/onboarding_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';
import 'package:little_learners/viewmodels/onboarding_viewmodel.dart';
import 'package:little_learners/views/onboarding/manual_page.dart';
import 'package:little_learners/views/onboarding/onboarding_language_page.dart';
import 'package:little_learners/views/onboarding/readiness_test_page.dart';
import 'package:provider/provider.dart';

void main() {
  group('OnboardingLanguagePage', () {
    testWidgets('offers both languages, English selected first',
        (tester) async {
      final onboarding = await _onboarding();
      await _pump(tester, const OnboardingLanguagePage(), onboarding);

      expect(find.text('Choose Language'), findsOneWidget);
      // Each option is named in its own script.
      expect(find.text('English'), findsWidgets);
      expect(find.text('اردو'), findsWidgets);
      expect(onboarding.language, OnboardingLanguage.english);
    });

    testWidgets('picking Urdu switches the whole screen to Urdu',
        (tester) async {
      final onboarding = await _onboarding();
      await _pump(tester, const OnboardingLanguagePage(), onboarding);

      await tester.tap(find.text('اردو').first);
      await tester.pumpAndSettle();

      expect(onboarding.language, OnboardingLanguage.urdu);
      expect(find.text('زبان منتخب کریں'), findsOneWidget);
      expect(find.text('جاری رکھیں'), findsOneWidget);
      expect(find.text('Choose Language'), findsNothing);
    });

    testWidgets('continue opens the readiness test', (tester) async {
      final onboarding = await _onboarding();
      await _pump(tester, const OnboardingLanguagePage(), onboarding);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(ReadinessTestPage), findsOneWidget);
      expect(find.byType(OnboardingLanguagePage), findsNothing);
    });
  });

  group('ReadinessTestPage', () {
    testWidgets('renders the English test by default', (tester) async {
      final onboarding = await _onboarding();
      await _pump(tester, const ReadinessTestPage(), onboarding);

      expect(find.text('Readiness Test'), findsOneWidget);
      expect(find.text(readinessQuestions.first.prompt), findsOneWidget);

      await _scrollTo(tester, find.text('Submit test'));
      expect(find.text('Submit test'), findsOneWidget);
    });

    testWidgets('renders the Urdu test right-to-left when chosen',
        (tester) async {
      final onboarding = await _onboarding();
      await onboarding.setLanguage(OnboardingLanguage.urdu);
      await _pump(tester, const ReadinessTestPage(), onboarding);

      expect(find.text('تیاری کا امتحان'), findsOneWidget);
      expect(find.text(readinessQuestionsUrdu.first.prompt), findsOneWidget);
      expect(find.text(readinessQuestions.first.prompt), findsNothing);

      await _scrollTo(tester, find.text('امتحان جمع کرائیں'));
      expect(find.text('امتحان جمع کرائیں'), findsOneWidget);

      final body = tester.widget<Directionality>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Directionality),
            )
            .last,
      );
      expect(body.textDirection, TextDirection.rtl);
    });

    testWidgets('the language toggle swaps the test in place', (tester) async {
      final onboarding = await _onboarding();
      await _pump(tester, const ReadinessTestPage(), onboarding);

      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();

      expect(onboarding.language, OnboardingLanguage.urdu);
      expect(find.text(readinessQuestionsUrdu.first.prompt), findsOneWidget);
    });
  });

  group('ManualPage', () {
    testWidgets('shows the guide in English and can switch to Urdu',
        (tester) async {
      final onboarding = await _onboarding();
      await _pump(tester, const ManualPage(), onboarding);

      expect(find.text('Parent Manual'), findsOneWidget);
      expect(find.text(manualPages.first.title), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();

      expect(find.text('والدین کی رہنما کتاب'), findsOneWidget);
      expect(find.text(manualPagesUrdu.first.title), findsOneWidget);
      expect(find.text('اگلا'), findsOneWidget);
    });

    testWidgets('the last guide page leads to the language picker',
        (tester) async {
      final onboarding = await _onboarding();
      await _pump(tester, const ManualPage(), onboarding);

      for (var page = 0; page < manualPages.length - 1; page++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Start readiness test'), findsOneWidget);

      await tester.tap(find.text('Start readiness test'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingLanguagePage), findsOneWidget);
    });
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<OnboardingViewModel> _onboarding() async {
  final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
  await viewModel.loadForParent('parent-1');
  return viewModel;
}

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  OnboardingViewModel onboarding,
) async {
  final auth = AuthViewModel(InMemoryAuthRepository());
  await auth.signUp(email: 'parent@example.com', password: 'StrongPass1!');

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
        ChangeNotifierProvider<OnboardingViewModel>.value(value: onboarding),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: page,
        routes: {
          RouteNames.onboardingLanguage: (_) => const OnboardingLanguagePage(),
          RouteNames.onboardingTest: (_) => const ReadinessTestPage(),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}
