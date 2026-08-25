import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_role.dart';
import 'package:little_learners/models/admin_stats.dart';
import 'package:little_learners/repositories/admin_auth_repository.dart';
import 'package:little_learners/repositories/admin_authorization_repository.dart';
import 'package:little_learners/repositories/admin_stats_repository.dart';

void main() {
  group('AdminStatsRepository', () {
    test('exposes system counts and module usage', () async {
      final repository = InMemoryAdminStatsRepository();

      final stats = await repository.loadStats();

      expect(stats.totalParentAccounts, greaterThan(0));
      expect(stats.totalChildProfiles, greaterThan(0));
      expect(stats.totalQuizzes, greaterThan(0));
      expect(stats.moduleUsage, isNotEmpty);
    });

    test('derives completion rate from attempts', () async {
      final stats = await InMemoryAdminStatsRepository().loadStats();

      expect(stats.attemptedLevelCount, greaterThan(0));
      expect(stats.completionRate, inInclusiveRange(0.0, 1.0));
    });

    test('empty stats report a zero completion rate rather than NaN', () {
      const stats = AdminStats.empty();

      expect(stats.attemptedLevelCount, 0);
      expect(stats.completionRate, 0);
    });

    test('blocks metric reads without an admin session', () async {
      final repository = AuthorizedAdminStatsRepository(
        delegate: InMemoryAdminStatsRepository(),
        authorizationRepository: AdminSessionAuthorizationRepository(
          InMemoryAdminAuthRepository(),
        ),
      );

      await expectLater(
        repository.loadStats(),
        throwsA(isA<AdminPermissionException>()),
      );
      await expectLater(
        repository.loadParentAccounts(),
        throwsA(isA<AdminPermissionException>()),
      );
    });

    test('allows metric reads for a signed-in admin', () async {
      final adminAuth = InMemoryAdminAuthRepository(
        admins: const {
          'admin@example.com': (
            password: 'Secret1!',
            role: AdminRole.superAdmin,
            isActive: true,
          ),
        },
      );
      await adminAuth.signIn(
        email: 'admin@example.com',
        password: 'Secret1!',
      );
      final repository = AuthorizedAdminStatsRepository(
        delegate: InMemoryAdminStatsRepository(),
        authorizationRepository:
            AdminSessionAuthorizationRepository(adminAuth),
      );

      final stats = await repository.loadStats();
      final accounts = await repository.loadParentAccounts();

      expect(stats.totalParentAccounts, greaterThan(0));
      expect(accounts, isNotEmpty);
    });
  });
}
