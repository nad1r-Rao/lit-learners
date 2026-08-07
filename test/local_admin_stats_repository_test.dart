import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/repositories/local_admin_stats_repository.dart';
import 'package:little_learners/services/local/child_profile_dao.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/local/progress_dao.dart';

ChildProfile _profile({
  required String id,
  required String parentId,
  String name = 'Ali',
}) {
  return ChildProfile(
    id: id,
    parentId: parentId,
    name: name,
    age: 4,
    avatarAsset: 'assets/images/koala/koala_guide_portrait.png',
    leaderboardOptIn: false,
    displayPreference: 'default',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    isSynced: false,
  );
}

LevelProgress _progress({
  required String childId,
  required String moduleId,
  required String levelId,
  required bool completed,
}) {
  return LevelProgress(
    childId: childId,
    moduleId: moduleId,
    levelId: levelId,
    completed: completed,
    starsEarned: completed ? 3 : 0,
    rewardEarned: completed,
    updatedAt: DateTime(2026, 1, 2),
    isSynced: false,
  );
}

void main() {
  group('LocalAdminStatsRepository', () {
    late InMemoryChildProfileDao profileDao;
    late InMemoryProgressDao progressDao;
    late InMemoryContentDao contentDao;

    setUp(() async {
      profileDao = InMemoryChildProfileDao();
      progressDao = InMemoryProgressDao();
      contentDao = InMemoryContentDao();

      await contentDao.seedContent(
        modules: [
          const LearningModule(
            id: 'math',
            title: 'Math',
            description: 'Numbers',
            category: ModuleCategory.math,
            minStage: 1,
            maxStage: 4,
            order: 1,
          ),
        ],
        levels: [
          const LearningLevel(
            id: 'math-1',
            moduleId: 'math',
            stage: 1,
            levelNumber: 1,
            title: 'Count to 3',
            subtitle: 'Counting',
            type: LevelType.counting,
            passingScore: 70,
            isBundled: true,
            contentItems: [
              ContentItem(
                title: 'One',
                prompt: 'Count one.',
                displayText: '1',
                visualLabel: 'One block',
              ),
            ],
            quizQuestions: [
              QuizQuestion(
                id: 'math-1-q1',
                prompt: 'How many?',
                options: ['1', '2'],
                correctIndex: 0,
              ),
              QuizQuestion(
                id: 'math-1-q2',
                prompt: 'And now?',
                options: ['1', '2'],
                correctIndex: 1,
              ),
            ],
          ),
        ],
      );
    });

    test('counts real profiles, quizzes and modules', () async {
      await profileDao.upsert(_profile(id: 'child-1', parentId: 'parent-1'));
      final repository = LocalAdminStatsRepository(
        childProfileDao: profileDao,
        progressDao: progressDao,
        contentDao: contentDao,
      );

      final stats = await repository.loadStats();

      expect(stats.totalChildProfiles, 1);
      expect(stats.totalQuizzes, 2);
      expect(stats.totalModules, 1);
      expect(stats.totalLevels, 1);
    });

    test('reflects newly added profiles instead of fixed demo numbers',
        () async {
      final repository = LocalAdminStatsRepository(
        childProfileDao: profileDao,
        progressDao: progressDao,
        contentDao: contentDao,
      );

      expect((await repository.loadStats()).totalChildProfiles, 0);

      await profileDao.upsert(_profile(id: 'child-1', parentId: 'parent-1'));

      expect((await repository.loadStats()).totalChildProfiles, 1);
    });

    test('aggregates module usage from recorded progress', () async {
      await progressDao.upsert(
        _progress(
          childId: 'child-1',
          moduleId: 'math',
          levelId: 'math-1',
          completed: true,
        ),
      );
      await progressDao.upsert(
        _progress(
          childId: 'child-2',
          moduleId: 'math',
          levelId: 'math-1',
          completed: false,
        ),
      );
      final repository = LocalAdminStatsRepository(
        childProfileDao: profileDao,
        progressDao: progressDao,
        contentDao: contentDao,
      );

      final stats = await repository.loadStats();
      final usage = stats.moduleUsage.single;

      expect(usage.moduleId, 'math');
      expect(usage.moduleTitle, 'Math');
      expect(usage.attemptedLevelCount, 2);
      expect(usage.completedLevelCount, 1);
      expect(usage.learnersEngaged, 2);
      expect(stats.completedLevelCount, 1);
    });

    test('lists registered parents when a directory is available', () async {
      final authRepository = InMemoryAuthRepository();
      final parent = await authRepository.signUp(
        email: 'parent@example.com',
        password: 'Strong1!',
      );
      await profileDao.upsert(_profile(id: 'child-1', parentId: parent.id));
      final repository = LocalAdminStatsRepository(
        childProfileDao: profileDao,
        progressDao: progressDao,
        contentDao: contentDao,
        parentDirectory: authRepository,
      );

      final accounts = await repository.loadParentAccounts();
      final stats = await repository.loadStats();

      expect(accounts, hasLength(1));
      expect(accounts.single.email, 'parent@example.com');
      expect(accounts.single.childProfileCount, 1);
      expect(stats.totalParentAccounts, 1);
    });

    test('excludes profiles whose parent account no longer exists', () async {
      final authRepository = InMemoryAuthRepository();
      final parent = await authRepository.signUp(
        email: 'parent@example.com',
        password: 'Strong1!',
      );
      // A profile left over from an earlier session, whose in-memory parent
      // account is gone.
      await profileDao.upsert(_profile(id: 'stale-1', parentId: 'ghost-parent'));
      await profileDao.upsert(_profile(id: 'child-1', parentId: parent.id));
      final repository = LocalAdminStatsRepository(
        childProfileDao: profileDao,
        progressDao: progressDao,
        contentDao: contentDao,
        parentDirectory: authRepository,
      );

      final stats = await repository.loadStats();
      final accounts = await repository.loadParentAccounts();

      expect(stats.totalParentAccounts, 1);
      expect(stats.totalChildProfiles, 1);
      expect(accounts.single.childProfileCount, 1);
    });

    test('falls back to parents visible through their children', () async {
      await profileDao.upsert(_profile(id: 'child-1', parentId: 'parent-1'));
      final repository = LocalAdminStatsRepository(
        childProfileDao: profileDao,
        progressDao: progressDao,
        contentDao: contentDao,
      );

      final stats = await repository.loadStats();

      expect(stats.totalParentAccounts, 1);
    });
  });
}
