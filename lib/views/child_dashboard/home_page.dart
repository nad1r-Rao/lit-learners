import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../models/learning_module.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/module_card.dart';
import '../profile/child_selection_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ActiveChildSession>();
    final learning = context.watch<LearningViewModel>();
    final child = session.activeChild;

    if (child == null) return const _NoProfileChosen();

    return Scaffold(
      // The hero carries the greeting, so a second bar on top would only add
      // a seam across the gradient.
      extendBodyBehindAppBar: true,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _ChildHero(
              child: child,
              starsEarned: learning.totalStarsEarned,
              levelsCompleted: learning.completedLevelCount,
              onSwitchProfile: () {
                session.clear();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteNames.childSelection,
                  (route) => false,
                );
              },
              onOpenParentArea: () => _openParentArea(context),
            ),
            const SizedBox(height: 20),
            _ModuleSectionHeading(count: learning.modules.length),
            const SizedBox(height: 14),
            if (learning.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (learning.modules.isEmpty)
              const _NoModulesYet()
            else
              _ModuleGrid(
                modules: learning.modules,
                onOpen: (module) => _openModule(context, module),
              ),
          ],
        ),
      ),
    );
  }

  /// The way out of the child's part of the app, behind the same check that
  /// already guards profile edits and reports.
  void _openParentArea(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.parentDashboard,
      ),
    );
  }

  void _openModule(BuildContext context, LearningModule module) {
    final route = module.category == ModuleCategory.video
        ? RouteNames.videoLearning
        : RouteNames.moduleLevels;
    Navigator.of(context).pushNamed(route, arguments: module.id);
  }
}

class _ChildHero extends StatelessWidget {
  const _ChildHero({
    required this.child,
    required this.starsEarned,
    required this.levelsCompleted,
    required this.onSwitchProfile,
    required this.onOpenParentArea,
  });

  final ChildProfile child;
  final int starsEarned;
  final int levelsCompleted;
  final VoidCallback onSwitchProfile;
  final VoidCallback onOpenParentArea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.grape, AppColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.grape.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ChildAvatar(
                name: child.name,
                avatarValue: child.avatarAsset,
                radius: 27,
                borderColor: AppColors.honey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${child.name}!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ready for a learning adventure?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Switch profile',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                onPressed: onSwitchProfile,
                icon: const Icon(Icons.switch_account_rounded),
              ),
              const SizedBox(width: 6),
              ParentAreaButton(onPressed: onOpenParentArea),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.honey,
                  value: '$starsEarned',
                  label: starsEarned == 1 ? 'star' : 'stars',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.lime,
                  value: '$levelsCompleted',
                  label: levelsCompleted == 1 ? 'level done' : 'levels done',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.modules, required this.onOpen});

  final List<LearningModule> modules;
  final ValueChanged<LearningModule> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 500
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columnCount == 2 ? 0.84 : 0.9,
          ),
          itemBuilder: (context, index) {
            final module = modules[index];
            return ModuleCard(
              module: module,
              onTap: () => onOpen(module),
            );
          },
        );
      },
    );
  }
}

class _ModuleSectionHeading extends StatelessWidget {
  const _ModuleSectionHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.honey, AppColors.rose],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.explore_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick an adventure',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                count == 1 ? '1 module ready' : '$count modules ready',
                style: TextStyle(
                  color: AppColors.ink.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.auto_awesome, color: AppColors.rose),
      ],
    );
  }
}

class _NoModulesYet extends StatelessWidget {
  const _NoModulesYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.6)),
      ),
      child: const Column(
        children: [
          Icon(Icons.explore_off_rounded, size: 36, color: AppColors.violet),
          SizedBox(height: 10),
          Text(
            'No modules for this age yet',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Check the age on this profile, or ask an adult to add content.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoProfileChosen extends StatelessWidget {
  const _NoProfileChosen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.mint,
                child: Icon(
                  Icons.child_care,
                  size: 36,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose a learner profile first',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteNames.childSelection,
                  (route) => false,
                ),
                icon: const Icon(Icons.switch_account),
                label: const Text('Choose profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
