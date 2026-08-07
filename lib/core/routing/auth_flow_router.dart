import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parent_account.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import 'route_names.dart';

class AuthFlowRouter {
  const AuthFlowRouter._();

  static Future<void> routeAfterAuth({
    required BuildContext context,
    required ParentAccount parent,
    bool replace = true,
  }) async {
    final onboarding = context.read<OnboardingViewModel>();
    await onboarding.loadForParent(parent.id);
    if (!context.mounted) return;

    // The language picker, not the test itself: a parent returning to an
    // unfinished test still gets to choose the language it is written in.
    final route = !onboarding.manualCompleted
        ? RouteNames.onboardingManual
        : !onboarding.testPassed
            ? RouteNames.onboardingLanguage
            : RouteNames.profiles;

    if (replace) {
      Navigator.of(context).pushReplacementNamed(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }
}
