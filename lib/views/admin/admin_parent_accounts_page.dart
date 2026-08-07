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
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: stats.isLoading
              ? null
              : () => context.read<AdminStatsViewModel>().load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: stats.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (stats.errorMessage != null) ...[
                  Card(
                    color: const Color(0xFFFFEAE7),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.coral),
                          const SizedBox(width: 10),
                          Expanded(child: Text(stats.errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.people_outline,
                        label: 'Parent accounts',
                        value: '${stats.stats.totalParentAccounts}',
                        accent: AppColors.plum,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.child_care_outlined,
                        label: 'Child profiles',
                        value: '${stats.stats.totalChildProfiles}',
                        accent: AppColors.aqua,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Registered Parents',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'View only. Accounts cannot be edited or removed here.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                if (accounts.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No parent accounts registered yet.'),
                      ),
                    ),
                  )
                else
                  ...accounts.map(
                    (account) => _ParentAccountTile(account: account),
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
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEEEDFE),
          child: Icon(Icons.person_outline, color: AppColors.plum),
        ),
        title: Text(
          account.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          createdAt == null
              ? '${account.childProfileCount} child profile(s)'
              : '${account.childProfileCount} child profile(s) · joined '
                  '${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)}',
        ),
        trailing: Chip(
          label: Text('${account.childProfileCount}'),
          backgroundColor: const Color(0xFFE1F5EE),
        ),
      ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
