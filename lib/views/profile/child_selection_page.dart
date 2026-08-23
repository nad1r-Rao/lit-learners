import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/child_avatar.dart';

/// The screen a signed-in parent lands on: nothing but the learners' faces and
/// names, so the child can start on their own. Everything a parent needs sits
/// behind the one small door in the corner.
class ChildSelectionPage extends StatefulWidget {
  const ChildSelectionPage({super.key});

  @override
  State<ChildSelectionPage> createState() => _ChildSelectionPageState();
}

class _ChildSelectionPageState extends State<ChildSelectionPage> {
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ProfileViewModel>().loadProfiles(parent.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final profileVm = context.watch<ProfileViewModel>();

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _SelectionHero(
              onOpenParentArea: () => _openParentArea(context),
            ),
            const SizedBox(height: 22),
            if (profileVm.isLoading && profileVm.profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (profileVm.profiles.isEmpty)
              _NoLearnersYet(onAddLearner: () => _openAddLearner(context))
            else
              _LearnerGrid(
                profiles: profileVm.profiles,
                onSelect: (profile) => _startLearning(context, profile),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _startLearning(
    BuildContext context,
    ChildProfile profile,
  ) async {
    context.read<ActiveChildSession>().selectProfile(profile);
    await context.read<LearningViewModel>().loadForProfile(profile);
    if (!context.mounted) return;

    // Pushed rather than replaced: the back gesture lands the child right back
    // on the faces instead of dropping them out of the app.
    Navigator.of(context).pushNamed(RouteNames.childHome);
  }

  /// The parent area is a door out of the child's part of the app, so it opens
  /// through the same check that already guards profile edits and reports.
  void _openParentArea(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.parentDashboard,
      ),
    );
  }

  void _openAddLearner(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.profileEdit,
        successArguments: ProfileEditArgs(
          returnRoute: RouteNames.childSelection,
        ),
      ),
    );
  }
}

class _SelectionHero extends StatelessWidget {
  const _SelectionHero({required this.onOpenParentArea});

  final VoidCallback onOpenParentArea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/koala/koala_guide_portrait.png',
                height: 46,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              ParentAreaButton(onPressed: onOpenParentArea),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Who is learning today?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap your picture to start.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one way from a child screen into the parent dashboard. Shared so the
/// child home and this screen show the same door in the same place.
class ParentAreaButton extends StatelessWidget {
  const ParentAreaButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: 'Parent dashboard',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.honey,
        foregroundColor: AppColors.ink,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.family_restroom_rounded),
    );
  }
}

class _LearnerGrid extends StatelessWidget {
  const _LearnerGrid({required this.profiles, required this.onSelect});

  final List<ChildProfile> profiles;
  final ValueChanged<ChildProfile> onSelect;

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
          itemCount: profiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final profile = profiles[index];
            return _LearnerCard(
              profile: profile,
              onTap: () => onSelect(profile),
            );
          },
        );
      },
    );
  }
}

class _LearnerCard extends StatelessWidget {
  const _LearnerCard({required this.profile, required this.onTap});

  final ChildProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start learning as ${profile.name}',
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.lilac.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    child: ChildAvatar(
                      name: profile.name,
                      avatarValue: profile.avatarAsset,
                      radius: 44,
                      borderColor: AppColors.honey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoLearnersYet extends StatelessWidget {
  const _NoLearnersYet({required this.onAddLearner});

  final VoidCallback onAddLearner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          const Icon(Icons.child_care_rounded, size: 38, color: AppColors.plum),
          const SizedBox(height: 10),
          Text(
            'No learners yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask a grown-up to add a child profile.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddLearner,
            icon: const Icon(Icons.add_reaction_rounded),
            label: const Text('Add a learner'),
          ),
        ],
      ),
    );
  }
}
