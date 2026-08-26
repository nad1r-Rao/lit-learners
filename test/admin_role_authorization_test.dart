import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_role.dart';
import 'package:little_learners/repositories/admin_auth_repository.dart';
import 'package:little_learners/repositories/admin_authorization_repository.dart';
import 'package:little_learners/repositories/admin_stats_repository.dart';

InMemoryAdminAuthRepository repositoryFor(
  AdminRole role, {
  bool isActive = true,
}) {
  return InMemoryAdminAuthRepository(
    admins: {
      'admin@example.com': (
        password: 'Secret1!',
        role: role,
        isActive: isActive,
      ),
    },
  );
}

Future<AdminSessionAuthorizationRepository> signedInAs(
  AdminRole role, {
  bool isActive = true,
}) async {
  final auth = repositoryFor(role, isActive: isActive);
  await auth.signIn(email: 'admin@example.com', password: 'Secret1!');
  return AdminSessionAuthorizationRepository(auth);
}

void main() {
  group('role-aware admin authorization', () {
    test('a content admin may author content', () async {
      final authorization = await signedInAs(AdminRole.contentAdmin);

      await expectLater(authorization.requireContentAdmin(), completes);
      expect(await authorization.canManageContent(), isTrue);
    });

    test('an analytics viewer may not author content', () async {
      final authorization = await signedInAs(AdminRole.analyticsViewer);

      await expectLater(
        authorization.requireContentAdmin(),
        throwsA(isA<AdminPermissionException>()),
      );
      expect(await authorization.canManageContent(), isFalse);
    });

    test('every role may read statistics', () async {
      for (final role in AdminRole.values) {
        final authorization = await signedInAs(role);
        await expectLater(
          authorization.requireStatisticsAccess(),
          completes,
          reason: role.id,
        );
      }
    });

    test('only a super admin may read parent accounts', () async {
      final superAdmin = await signedInAs(AdminRole.superAdmin);
      final contentAdmin = await signedInAs(AdminRole.contentAdmin);

      await expectLater(superAdmin.requireParentAccountAccess(), completes);
      await expectLater(
        contentAdmin.requireParentAccountAccess(),
        throwsA(isA<AdminPermissionException>()),
      );
    });

    test('a suspended admin cannot sign in at all', () async {
      final auth = repositoryFor(AdminRole.superAdmin, isActive: false);

      await expectLater(
        auth.signIn(email: 'admin@example.com', password: 'Secret1!'),
        throwsA(
          isA<AdminAuthException>().having(
            (error) => error.message,
            'message',
            AdminAuthMessages.suspended,
          ),
        ),
      );
    });
  });

  group('stats repository honours roles', () {
    test('a content admin reads statistics but not parent accounts', () async {
      final authorization = await signedInAs(AdminRole.contentAdmin);
      final repository = AuthorizedAdminStatsRepository(
        delegate: InMemoryAdminStatsRepository(),
        authorizationRepository: authorization,
      );

      await expectLater(repository.loadStats(), completes);
      await expectLater(
        repository.loadParentAccounts(),
        throwsA(isA<AdminPermissionException>()),
      );
    });

    test('a super admin reads both', () async {
      final authorization = await signedInAs(AdminRole.superAdmin);
      final repository = AuthorizedAdminStatsRepository(
        delegate: InMemoryAdminStatsRepository(),
        authorizationRepository: authorization,
      );

      expect((await repository.loadStats()).totalParentAccounts, greaterThan(0));
      expect(await repository.loadParentAccounts(), isNotEmpty);
    });
  });
}
