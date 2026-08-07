import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/admin_stats.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_stats_viewmodel.dart';
import 'widgets/admin_scaffold.dart';

/// Requirement 5: system-wide usage and learning-performance statistics.
class AdminProgressStatisticsPage extends StatefulWidget {
  const AdminProgressStatisticsPage({super.key});

  @override
  State<AdminProgressStatisticsPage> createState() =>
      _AdminProgressStatisticsPageState();
}

class _AdminProgressStatisticsPageState
    extends State<AdminProgressStatisticsPage> {
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
    final viewModel = context.watch<AdminStatsViewModel>();
    final stats = viewModel.stats;

    return AdminScaffold(
      title: 'Progress Statistics',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: viewModel.isLoading
              ? null
              : () => context.read<AdminStatsViewModel>().load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (viewModel.errorMessage != null) ...[
                  Card(
                    color: const Color(0xFFFFEAE7),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.coral),
                          const SizedBox(width: 10),
                          Expanded(child: Text(viewModel.errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'System Usage',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.people_outline,
                        label: 'Registered parents',
                        value: '${stats.totalParentAccounts}',
                        accent: AppColors.plum,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.child_care_outlined,
                        label: 'Child profiles',
                        value: '${stats.totalChildProfiles}',
                        accent: AppColors.aqua,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.widgets_outlined,
                        label: 'Modules',
                        value: '${stats.totalModules}',
                        accent: AppColors.sky,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.map_outlined,
                        label: 'Levels',
                        value: '${stats.totalLevels}',
                        accent: AppColors.forest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.task_alt_outlined,
                        label: 'Levels completed',
                        value: '${stats.completedLevelCount}',
                        accent: AppColors.leaf,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.percent_outlined,
                        label: 'Completion rate',
                        value: _percent(stats.completionRate),
                        accent: AppColors.honey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Module Usage',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level attempts and completions recorded across all learners.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                if (stats.moduleUsage.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No learning activity recorded yet.'),
                      ),
                    ),
                  )
                else
                  ...stats.moduleUsage.map(
                    (usage) => _ModuleUsageCard(usage: usage),
                  ),
              ],
            ),
    );
  }
}

class _ModuleUsageCard extends StatelessWidget {
  const _ModuleUsageCard({required this.usage});

  final AdminModuleUsage usage;

  @override
  Widget build(BuildContext context) {
    final textDirection = LearningTextDirection.forText(usage.moduleTitle);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: textDirection,
                    child: Text(
                      usage.moduleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LearningTextDirection.styleForText(
                        Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                        usage.moduleTitle,
                      ),
                    ),
                  ),
                ),
                Text(
                  _percent(usage.completionRate),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: usage.completionRate.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.line,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _UsageChip(
                  icon: Icons.play_circle_outline,
                  label: '${usage.attemptedLevelCount} attempted',
                ),
                _UsageChip(
                  icon: Icons.task_alt_outlined,
                  label: '${usage.completedLevelCount} completed',
                ),
                _UsageChip(
                  icon: Icons.groups_outlined,
                  label: '${usage.learnersEngaged} learners',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

String _percent(double ratio) => '${(ratio * 100).round()}%';
