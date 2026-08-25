import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parent_account.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import 'app_router.dart';
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

    if (!onboarding.manualCompleted) {
      _go(context, RouteNames.onboardingManual, replace: replace);
      return;
    }
    // The language picker, not the test itself: a parent returning to an
    // unfinished test still gets to choose the language it is written in.
    if (!onboarding.testPassed) {
      _go(context, RouteNames.onboardingLanguage, replace: replace);
      return;
    }

    await routeToChildArea(
      context: context,
      parentId: parent.id,
      replace: replace,
    );
  }

  /// Where a parent who has finished onboarding belongs: the child selection
  /// screen, or the create form while there is still nobody to select. The
  /// parent dashboard is never on this path — it is reached on purpose, from
  /// the parent-area button on the child screens.
  static Future<void> routeToChildArea({
    required BuildContext context,
    required String parentId,
    bool replace = true,
  }) async {
    final profiles = context.read<ProfileViewModel>();
    await profiles.loadProfiles(parentId);
    if (!context.mounted) return;

    if (profiles.profiles.isEmpty) {
      _go(
        context,
        RouteNames.profileEdit,
        replace: replace,
        arguments: const ProfileEditArgs(
          returnRoute: RouteNames.childSelection,
        ),
      );
      return;
    }

    _go(context, RouteNames.childSelection, replace: replace);
  }

  static void _go(
    BuildContext context,
    String route, {
    required bool replace,
    Object? arguments,
  }) {
    if (replace) {
      Navigator.of(context).pushReplacementNamed(route, arguments: arguments);
    } else {
      Navigator.of(context).pushNamed(route, arguments: arguments);
    }
  }
}
