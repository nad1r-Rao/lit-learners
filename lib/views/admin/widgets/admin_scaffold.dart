import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/route_names.dart';
import '../../../viewmodels/admin_auth_viewmodel.dart';
import '../../../viewmodels/admin_stats_viewmodel.dart';

/// Shared chrome for admin screens.
///
/// Guards every page behind the admin session so a deep link cannot bypass
/// UC-18, and hosts the UC-20 logout affordance.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.showLogout = false,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool showLogout;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthViewModel>();

    if (!adminAuth.isAuthenticated) {
      return const AdminAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          if (showLogout)
            IconButton(
              tooltip: 'Log out',
              onPressed: adminAuth.isLoading
                  ? null
                  : () => confirmAdminLogout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: SafeArea(child: child),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// UC-20: confirm, terminate the session, return to the admin login screen.
Future<void> confirmAdminLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'This will end your admin session and return you to the login screen.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Yes, log out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final adminAuth = context.read<AdminAuthViewModel>();
  final statsViewModel = context.read<AdminStatsViewModel>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final signedOut = await adminAuth.signOut();

  if (!signedOut) {
    // Alternative flow: logout failed, offer a retry rather than stranding
    // the admin in a half-open session.
    messenger.showSnackBar(
      SnackBar(
        content: Text(adminAuth.errorMessage ?? 'Logout failed.'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            if (context.mounted) confirmAdminLogout(context);
          },
        ),
      ),
    );
    return;
  }

  statsViewModel.reset();
  await navigator.pushNamedAndRemoveUntil(
    RouteNames.adminLogin,
    (route) => false,
  );
}

class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.coral),
                const SizedBox(height: 12),
                Text(
                  'Access Denied: Admin Rights Required',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(
                        RouteNames.adminLogin,
                        (route) => false,
                      ),
                  child: const Text('Go to admin login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact metric tile shared by the dashboard and statistics screens.
class AdminMetricTile extends StatelessWidget {
  const AdminMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.sky,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
