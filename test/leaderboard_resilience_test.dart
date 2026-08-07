import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/leaderboard_entry.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/repositories/child_profile_repository.dart';
import 'package:little_learners/repositories/leaderboard_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/sync/leaderboard_sync_service.dart';
import 'package:little_learners/viewmodels/leaderboard_viewmodel.dart';

void main() {
  // The reported bug: publishing this parent's own scores threw, and the whole
  // board was replaced with "Leaderboard could not load." even though the
  // entries themselves were readable.
  test('a failing publish step still shows the board', () async {
    final repository = _FakeLeaderboardRepository({
      3: [_entry(childId: 'other-child', totalScore: 250)],
    });
    final viewModel = LeaderboardViewModel(
      leaderboardRepository: repository,
      leaderboardSyncService: _failingSyncService(),
    );

    await viewModel.loadLeaderboard(parentId: 'parent-1', stage: 3);

    expect(viewModel.entries.single.childId, 'other-child');
    expect(viewModel.errorMessage, isNull);
  });

  test('a failing read is still reported', () async {
    final viewModel = LeaderboardViewModel(
      leaderboardRepository: const _BrokenLeaderboardRepository(),
    );

    await viewModel.loadLeaderboard(stage: 3);

    expect(viewModel.entries, isEmpty);
    expect(viewModel.errorMessage, 'Leaderboard could not load.');
  });

  test('a recovered load clears the previous error', () async {
    final repository = _FakeLeaderboardRepository({
      3: [_entry(childId: 'child-1', totalScore: 120)],
    });
    final viewModel = LeaderboardViewModel(
      leaderboardRepository: repository,
      leaderboardSyncService: _failingSyncService(),
    );

    await viewModel.loadLeaderboard(parentId: 'parent-1', stage: 3);

    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });
}

/// A real sync service wired to a repository that fails, which is how the bug
/// showed up in the app: publishing threw and took the whole screen with it.
LeaderboardSyncService _failingSyncService() {
  return LeaderboardSyncService(
    childProfileRepository: const _ThrowingChildProfileRepository(),
    progressRepository: InMemoryProgressRepository(),
    leaderboardRepository: const _BrokenLeaderboardRepository(),
  );
}

class _ThrowingChildProfileRepository implements ChildProfileRepository {
  const _ThrowingChildProfileRepository();

  @override
  Future<List<ChildProfile>> getProfiles(String parentId) async {
    throw StateError('profile sync failed');
  }

  @override
  Future<ChildProfile> createProfile({
    required String parentId,
    required String name,
    required int age,
    required String avatarAsset,
    required bool leaderboardOptIn,
    required String displayPreference,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChildProfile> updateProfile(ChildProfile profile) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProfile({
    required String parentId,
    required String childId,
  }) {
    throw UnimplementedError();
  }
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  const _FakeLeaderboardRepository(this.entriesByStage);

  final Map<int, List<LeaderboardEntry>> entriesByStage;

  @override
  Future<void> deleteEntryForChild(String childId) async {}

  @override
  Future<List<LeaderboardEntry>> getTopEntries({
    required int age,
    int limit = 20,
  }) async {
    return entriesByStage[age] ?? const [];
  }

  @override
  Future<LeaderboardEntry?> refreshEntry({
    required ChildProfile profile,
    required List<LevelProgress> progress,
  }) async {
    return null;
  }
}

class _BrokenLeaderboardRepository implements LeaderboardRepository {
  const _BrokenLeaderboardRepository();

  @override
  Future<void> deleteEntryForChild(String childId) async {}

  @override
  Future<List<LeaderboardEntry>> getTopEntries({
    required int age,
    int limit = 20,
  }) async {
    throw StateError('read failed');
  }

  @override
  Future<LeaderboardEntry?> refreshEntry({
    required ChildProfile profile,
    required List<LevelProgress> progress,
  }) async {
    return null;
  }
}

LeaderboardEntry _entry({
  required String childId,
  required int totalScore,
}) {
  return LeaderboardEntry(
    childId: childId,
    parentId: 'parent-2',
    displayName: childId,
    ageStage: 3,
    totalScore: totalScore,
    completedLevels: 1,
    totalStars: 3,
    rewardCount: 1,
    lastActivityAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}
