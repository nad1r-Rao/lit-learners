import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/admin_stats.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_stats_viewmodel.dart';
import 'widgets/admin_scaffold.dart';

/// Requirement 4: monitoring-only view of registered parent accounts.
///
/// Intentionally read-only — there are no edit or delete affordances here.
class AdminParentAccountsPage extends StatefulWidget {
  const AdminParentAccountsPage({super.key});

  @override
  State<AdminParentAccountsPage> createState() =>
      _AdminParentAccountsPageState();
}

class _AdminParentAccountsPageState extends State<AdminParentAccountsPage> {
  var _didRequestLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAdmin = context.watch<AdminAuthViewModel>().isAuthenticated;
    final stats = context.read<AdminStatsViewModel>();
    if (isAdmin && !_didRequestLoad && !stats.hasLoaded) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminStatsViewModel>().load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<AdminStatsViewModel>();
    final accounts = stats.parentAccounts;

    return AdminScaffold(
      title: 'Parent Accounts',
      subtitle: 'Monitoring only',
      actions: [
        AdminHeaderAction(
          tooltip: 'Refresh',
          icon: Icons.refresh,
          onPressed: stats.isLoading
              ? null
              : () => context.read<AdminStatsViewModel>().load(),
        ),
      ],
      child: stats.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (stats.errorMessage != null) ...[
                  AdminInlineError(message: stats.errorMessage!),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.people_alt_rounded,
                        label: 'Parent accounts',
                        value: '${stats.stats.totalParentAccounts}',
                        accent: AppColors.plum,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.child_care_rounded,
                        label: 'Child profiles',
                        value: '${stats.stats.totalChildProfiles}',
                        accent: AppColors.aqua,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const AdminSectionHeading(
                  title: 'Registered Parents',
                  subtitle:
                      'View only. Accounts cannot be edited or removed here.',
                ),
                const SizedBox(height: 10),
                if (accounts.isEmpty)
                  const AdminEmptyState(
                    icon: Icons.family_restroom_rounded,
                    title: 'No parent accounts yet',
                    message:
                        'Accounts appear here as soon as a parent registers '
                        'in the app.',
                  )
                else
                  ...accounts.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ParentAccountTile(account: account),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ParentAccountTile extends StatelessWidget {
  const _ParentAccountTile({required this.account});

  final AdminParentAccountSummary account;

  @override
  Widget build(BuildContext context) {
    final createdAt = account.createdAt;

    return AdminSoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const AdminIconChip(
            icon: Icons.person_rounded,
            color: AppColors.plum,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AdminPill(
                      icon: Icons.child_care_rounded,
                      label: '${account.childProfileCount} '
                          '${account.childProfileCount == 1 ? 'child' : 'children'}',
                      accent: AppColors.aqua,
                    ),
                    if (createdAt != null)
                      AdminPill(
                        icon: Icons.calendar_today_rounded,
                        label: 'Joined ${createdAt.year}-'
                            '${_two(createdAt.month)}-${_two(createdAt.day)}',
                        accent: AppColors.violet,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
