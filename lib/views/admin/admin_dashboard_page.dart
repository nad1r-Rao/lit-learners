import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_stats_viewmodel.dart';
import 'widgets/admin_scaffold.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  var _didRequestLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAdmin = context.watch<AdminAuthViewModel>().isAuthenticated;
    if (isAdmin && !_didRequestLoad) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminStatsViewModel>().load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthViewModel>();
    final stats = context.watch<AdminStatsViewModel>();

    return AdminScaffold(
      title: 'Admin Dashboard',
      showLogout: true,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: stats.isLoading
              ? null
              : () => context.read<AdminStatsViewModel>().load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                  color: AppColors.panel,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.sky,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminAuth.admin?.role.label ?? 'Admin Portal',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      adminAuth.admin?.displayLabel ?? 'Admin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (stats.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (stats.errorMessage != null) ...[
              _ErrorBanner(message: stats.errorMessage!),
              const SizedBox(height: 12),
            ],
            _SystemSnapshot(stats: stats),
            const SizedBox(height: 18),
            Text(
              'Admin Menu',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            // Each entry is hidden rather than disabled when the role cannot
            // use it, so the menu shows only what this admin can actually do.
            if (adminAuth.admin?.canManageContent ?? false) ...[
              _AdminMenuTile(
                title: 'Manage Content',
                subtitle: 'Modules, levels, quizzes and media',
                icon: Icons.book_outlined,
                iconColor: AppColors.sky,
                backgroundColor: const Color(0xFFE6F1FB),
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.adminContent),
              ),
              const SizedBox(height: 10),
            ],
            if (adminAuth.admin?.canViewParentAccounts ?? false) ...[
              _AdminMenuTile(
                title: 'View Parent Accounts',
                subtitle: 'Registered parents (monitoring only)',
                icon: Icons.family_restroom_outlined,
                iconColor: AppColors.plum,
                backgroundColor: const Color(0xFFEEEDFE),
                onTap: () => Navigator.of(context)
                    .pushNamed(RouteNames.adminParentAccounts),
              ),
              const SizedBox(height: 10),
            ],
            _AdminMenuTile(
              title: 'View Progress Statistics',
              subtitle: 'Module usage and level completion',
              icon: Icons.insights_outlined,
              iconColor: AppColors.leaf,
              backgroundColor: const Color(0xFFE1F5EE),
              onTap: () => Navigator.of(context)
                  .pushNamed(RouteNames.adminProgressStatistics),
            ),
            const SizedBox(height: 10),
            _AdminMenuTile(
              title: 'Admin Logout',
              subtitle: 'End this admin session',
              icon: Icons.logout_rounded,
              iconColor: AppColors.coral,
              backgroundColor: const Color(0xFFFFEAE7),
              onTap: () => confirmAdminLogout(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Requirement 1: the three counts shown immediately after a successful login.
class _SystemSnapshot extends StatelessWidget {
  const _SystemSnapshot({required this.stats});

  final AdminStatsViewModel stats;

  @override
  Widget build(BuildContext context) {
    final data = stats.stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Snapshot',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            AdminMetricTile(
              icon: Icons.child_care_outlined,
              label: 'Child profiles',
              value: '${data.totalChildProfiles}',
              accent: AppColors.aqua,
            ),
            const SizedBox(height: 8),
            AdminMetricTile(
              icon: Icons.people_outline,
              label: 'Registered parent accounts',
              value: '${data.totalParentAccounts}',
              accent: AppColors.plum,
            ),
            const SizedBox(height: 8),
            AdminMetricTile(
              icon: Icons.quiz_outlined,
              label: 'Quizzes uploaded',
              value: '${data.totalQuizzes}',
              accent: AppColors.honey,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFEAE7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.coral),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  const _AdminMenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
