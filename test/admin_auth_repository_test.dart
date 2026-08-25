import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_role.dart';
import 'package:little_learners/repositories/admin_auth_repository.dart';

void main() {
  group('InMemoryAdminAuthRepository', () {
    test('signs in a seeded admin and exposes the admin role', () async {
      final repository = InMemoryAdminAuthRepository(
        admins: const {
          'admin@example.com': (
            password: 'Secret1!',
            role: AdminRole.superAdmin,
            isActive: true,
          ),
        },
      );

      final admin = await repository.signIn(
        email: 'admin@example.com',
        password: 'Secret1!',
      );

      expect(admin.role, AdminRole.superAdmin);
      expect(admin.canManageContent, isTrue);
      expect(await repository.currentAdmin(), isNotNull);
    });

    test('normalizes email casing and surrounding whitespace', () async {
      final repository = InMemoryAdminAuthRepository(
        admins: const {
          'admin@example.com': (
            password: 'Secret1!',
            role: AdminRole.superAdmin,
            isActive: true,
          ),
        },
      );

      final admin = await repository.signIn(
        email: '  Admin@Example.COM ',
        password: 'Secret1!',
      );

      expect(admin.email, 'admin@example.com');
    });

    test('rejects a wrong password with the UC-18 message', () async {
      final repository = InMemoryAdminAuthRepository(
        admins: const {
          'admin@example.com': (
            password: 'Secret1!',
            role: AdminRole.superAdmin,
            isActive: true,
          ),
        },
      );

      await expectLater(
        repository.signIn(email: 'admin@example.com', password: 'nope'),
        throwsA(
          isA<AdminAuthException>().having(
            (error) => error.message,
            'message',
            AdminAuthMessages.invalidCredentials,
          ),
        ),
      );
      expect(await repository.currentAdmin(), isNull);
    });

    test('rejects an unknown account without revealing which half failed',
        () async {
      final repository = InMemoryAdminAuthRepository(
        admins: const {
          'admin@example.com': (
            password: 'Secret1!',
            role: AdminRole.superAdmin,
            isActive: true,
          ),
        },
      );

      await expectLater(
        repository.signIn(email: 'parent@example.com', password: 'Secret1!'),
        throwsA(
          isA<AdminAuthException>().having(
            (error) => error.message,
            'message',
            AdminAuthMessages.invalidCredentials,
          ),
        ),
      );
    });

    test('signing out clears the session (UC-20)', () async {
      final repository = InMemoryAdminAuthRepository(
        admins: const {
          'admin@example.com': (
            password: 'Secret1!',
            role: AdminRole.superAdmin,
            isActive: true,
          ),
        },
      );
      await repository.signIn(
        email: 'admin@example.com',
        password: 'Secret1!',
      );

      await repository.signOut();

      expect(await repository.currentAdmin(), isNull);
    });
  });
}
