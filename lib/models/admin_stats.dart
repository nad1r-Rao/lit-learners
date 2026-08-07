/// Read-only system metrics for the admin portal.
///
/// Backs the dashboard counts (requirement 1) and the progress statistics
/// screen (requirement 5).
class AdminStats {
  const AdminStats({
    required this.totalParentAccounts,
    required this.totalChildProfiles,
    required this.totalQuizzes,
    required this.totalModules,
    required this.totalLevels,
    required this.completedLevelCount,
    required this.moduleUsage,
  });

  const AdminStats.empty()
      : totalParentAccounts = 0,
        totalChildProfiles = 0,
        totalQuizzes = 0,
        totalModules = 0,
        totalLevels = 0,
        completedLevelCount = 0,
        moduleUsage = const [];

  final int totalParentAccounts;
  final int totalChildProfiles;
  final int totalQuizzes;
  final int totalModules;
  final int totalLevels;
  final int completedLevelCount;
  final List<AdminModuleUsage> moduleUsage;

  /// Total level attempts recorded across every child.
  int get attemptedLevelCount =>
      moduleUsage.fold(0, (sum, usage) => sum + usage.attemptedLevelCount);

  /// Share of recorded attempts that reached completion, 0..1.
  double get completionRate {
    final attempted = attemptedLevelCount;
    if (attempted == 0) return 0;
    return completedLevelCount / attempted;
  }
}

/// Per-module engagement, used for the "module usage" breakdown.
class AdminModuleUsage {
  const AdminModuleUsage({
    required this.moduleId,
    required this.moduleTitle,
    required this.attemptedLevelCount,
    required this.completedLevelCount,
    required this.learnersEngaged,
  });

  final String moduleId;
  final String moduleTitle;
  final int attemptedLevelCount;
  final int completedLevelCount;
  final int learnersEngaged;

  double get completionRate {
    if (attemptedLevelCount == 0) return 0;
    return completedLevelCount / attemptedLevelCount;
  }
}

/// A parent account row for the monitoring-only account list (requirement 4).
class AdminParentAccountSummary {
  const AdminParentAccountSummary({
    required this.parentId,
    required this.email,
    required this.childProfileCount,
    this.createdAt,
  });

  final String parentId;
  final String email;
  final int childProfileCount;
  final DateTime? createdAt;
}
