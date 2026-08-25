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
      subtitle: 'Across every learner',
      actions: [
        AdminHeaderAction(
          tooltip: 'Refresh',
          icon: Icons.refresh,
          onPressed: viewModel.isLoading
              ? null
              : () => context.read<AdminStatsViewModel>().load(),
        ),
      ],
      child: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (viewModel.errorMessage != null) ...[
                  AdminInlineError(message: viewModel.errorMessage!),
                  const SizedBox(height: 12),
                ],
                _CompletionSummary(stats: stats),
                const SizedBox(height: 18),
                const AdminSectionHeading(title: 'System Usage'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.people_alt_rounded,
                        label: 'Registered parents',
                        value: '${stats.totalParentAccounts}',
                        accent: AppColors.plum,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.child_care_rounded,
                        label: 'Child profiles',
                        value: '${stats.totalChildProfiles}',
                        accent: AppColors.aqua,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.widgets_rounded,
                        label: 'Modules',
                        value: '${stats.totalModules}',
                        accent: AppColors.sky,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.map_rounded,
                        label: 'Levels',
                        value: '${stats.totalLevels}',
                        accent: AppColors.forest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.task_alt_rounded,
                        label: 'Levels completed',
                        value: '${stats.completedLevelCount}',
                        accent: AppColors.leaf,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminMetricTile(
                        icon: Icons.play_circle_rounded,
                        label: 'Levels attempted',
                        value: '${stats.attemptedLevelCount}',
                        accent: AppColors.honey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const AdminSectionHeading(
                  title: 'Module Usage',
                  subtitle: 'Level attempts and completions recorded across '
                      'all learners.',
                ),
                const SizedBox(height: 10),
                if (stats.moduleUsage.isEmpty)
                  const AdminEmptyState(
                    icon: Icons.insights_rounded,
                    title: 'No learning activity yet',
                    message: 'Usage appears here once children start playing '
                        'through the levels.',
                  )
                else
                  ...stats.moduleUsage.map(
                    (usage) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModuleUsageCard(usage: usage),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Overall completion, given the prominence the headline number deserves.
///
/// Not the rich charts that are still on the backlog — just the one figure the
/// rest of the screen breaks down.
class _CompletionSummary extends StatelessWidget {
  const _CompletionSummary({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final rate = stats.completionRate;

    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AdminIconChip(
                icon: Icons.donut_large_rounded,
                color: AppColors.violet,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall completion',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stats.completedLevelCount} of '
                      '${stats.attemptedLevelCount} attempted levels finished',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.66),
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                _percent(rate),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AdminProgressBar(value: rate, minHeight: 8),
        ],
      ),
    );
  }
}

class _ModuleUsageCard extends StatelessWidget {
  const _ModuleUsageCard({required this.usage});

  final AdminModuleUsage usage;

  /// Stable per-module accent, so a module keeps its colour between reloads
  /// rather than shifting with list order.
  Color get _accent {
    const palette = [
      AppColors.sky,
      AppColors.leaf,
      AppColors.plum,
      AppColors.coral,
      AppColors.aqua,
      AppColors.honey,
      AppColors.rose,
      AppColors.violet,
    ];
    return palette[usage.moduleId.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = LearningTextDirection.forText(usage.moduleTitle);
    final accent = _accent;

    return AdminSoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminIconChip(
                icon: Icons.auto_stories_rounded,
                color: accent,
                size: 38,
              ),
              const SizedBox(width: 10),
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
              const SizedBox(width: 8),
              Text(
                _percent(usage.completionRate),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AdminProgressBar(value: usage.completionRate, color: accent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AdminPill(
                icon: Icons.play_circle_rounded,
                label: '${usage.attemptedLevelCount} attempted',
                accent: AppColors.sky,
              ),
              AdminPill(
                icon: Icons.task_alt_rounded,
                label: '${usage.completedLevelCount} completed',
                accent: AppColors.leaf,
              ),
              AdminPill(
                icon: Icons.groups_rounded,
                label: '${usage.learnersEngaged} learners',
                accent: AppColors.plum,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _percent(double ratio) => '${(ratio * 100).round()}%';
