import '../models/admin_stats.dart';
import '../models/child_profile.dart';
import '../models/learning_level.dart';
import '../models/parent_account.dart';
import '../services/local/child_profile_dao.dart';
import '../services/local/content_dao.dart';
import '../services/local/progress_dao.dart';
import 'admin_stats_repository.dart';
import 'auth_repository.dart';

/// Admin metrics computed from live local data.
///
/// Used when the app runs without Firebase so the dashboard reflects what is
/// actually in the app rather than placeholder numbers.
class LocalAdminStatsRepository implements AdminStatsRepository {
  const LocalAdminStatsRepository({
    required ChildProfileDao childProfileDao,
    required ProgressDao progressDao,
    required ContentDao contentDao,
    ParentDirectory? parentDirectory,
  })  : _childProfileDao = childProfileDao,
        _progressDao = progressDao,
        _contentDao = contentDao,
        _parentDirectory = parentDirectory;

  final ChildProfileDao _childProfileDao;
  final ProgressDao _progressDao;
  final ContentDao _contentDao;
  final ParentDirectory? _parentDirectory;

  @override
  Future<AdminStats> loadStats() async {
    final progress = await _progressDao.getAll();
    final modules = await _contentDao.getModules();
    final parents = await _parentDirectory?.allParents();
    final profiles = _ownedProfiles(
      await _childProfileDao.getAll(),
      parents,
    );

    final levels = <LearningLevel>[];
    for (final module in modules) {
      levels.addAll(await _contentDao.getLevelsForModule(module.id));
    }

    final moduleTitles = {
      for (final module in modules) module.id: module.title,
    };

    final quizCount = levels.fold<int>(
      0,
      (sum, level) => sum + level.quizQuestions.length,
    );

    // Without a directory, fall back to the distinct parents that own a cached
    // profile — an undercount, but never a fabricated number.
    final parentCount = parents?.length ??
        profiles.map((profile) => profile.parentId).toSet().length;

    final attempted = <String, int>{};
    final completed = <String, int>{};
    final learners = <String, Set<String>>{};

    for (final entry in progress) {
      final moduleId = entry.moduleId;
      if (moduleId.isEmpty) continue;

      attempted[moduleId] = (attempted[moduleId] ?? 0) + 1;
      if (entry.completed) {
        completed[moduleId] = (completed[moduleId] ?? 0) + 1;
      }
      learners.putIfAbsent(moduleId, () => <String>{}).add(entry.childId);
    }

    final usage = attempted.keys
        .map(
          (moduleId) => AdminModuleUsage(
            moduleId: moduleId,
            moduleTitle: moduleTitles[moduleId] ?? moduleId,
            attemptedLevelCount: attempted[moduleId] ?? 0,
            completedLevelCount: completed[moduleId] ?? 0,
            learnersEngaged: learners[moduleId]?.length ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.attemptedLevelCount.compareTo(a.attemptedLevelCount));

    return AdminStats(
      totalParentAccounts: parentCount,
      totalChildProfiles: profiles.length,
      totalQuizzes: quizCount,
      totalModules: modules.length,
      totalLevels: levels.length,
      completedLevelCount: progress.where((entry) => entry.completed).length,
      moduleUsage: usage,
    );
  }

  /// Drops profiles whose parent account no longer exists.
  ///
  /// The local profile cache outlives an in-memory account store, so without
  /// this the dashboard reports child profiles left over from earlier sessions
  /// alongside a parent count that resets — two numbers measured over
  /// different lifetimes. With no directory to check against, every cached
  /// profile is kept.
  List<ChildProfile> _ownedProfiles(
    List<ChildProfile> profiles,
    List<ParentAccount>? parents,
  ) {
    if (parents == null) return profiles;
    final knownParentIds = parents.map((parent) => parent.id).toSet();
    return profiles
        .where((profile) => knownParentIds.contains(profile.parentId))
        .toList();
  }

  @override
  Future<List<AdminParentAccountSummary>> loadParentAccounts() async {
    final parents = await _parentDirectory?.allParents();
    final profiles = _ownedProfiles(
      await _childProfileDao.getAll(),
      parents,
    );
    final childCounts = <String, int>{};
    for (final profile in profiles) {
      childCounts[profile.parentId] = (childCounts[profile.parentId] ?? 0) + 1;
    }

    if (parents != null) {
      return parents
          .map(
            (parent) => AdminParentAccountSummary(
              parentId: parent.id,
              email: parent.email,
              childProfileCount: childCounts[parent.id] ?? 0,
              createdAt: parent.createdAt,
            ),
          )
          .toList();
    }

    // No directory available: report the parents visible through their
    // children rather than inventing rows.
    return childCounts.entries
        .map(
          (entry) => AdminParentAccountSummary(
            parentId: entry.key,
            email: entry.key,
            childProfileCount: entry.value,
          ),
        )
        .toList();
  }
}
