import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_role.dart';
import 'package:little_learners/repositories/admin_auth_repository.dart';
import 'package:little_learners/viewmodels/admin_auth_viewmodel.dart';

class _FailingSignOutAdminAuthRepository extends InMemoryAdminAuthRepository {
  _FailingSignOutAdminAuthRepository()
      : super(
          admins: const {
            'admin@example.com': (
              password: 'Secret1!',
              role: AdminRole.superAdmin,
              isActive: true,
            ),
          },
        );

  @override
  Future<void> signOut() async {
    throw const AdminAuthException('network unavailable');
  }
}

void main() {
  group('AdminAuthViewModel', () {
    test('authenticates a valid admin', () async {
      final viewModel = AdminAuthViewModel(
        InMemoryAdminAuthRepository(
          admins: const {
            'admin@example.com': (
              password: 'Secret1!',
              role: AdminRole.superAdmin,
              isActive: true,
            ),
          },
        ),
      );

      final result = await viewModel.signIn(
        email: 'admin@example.com',
        password: 'Secret1!',
      );

      expect(result, isTrue);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.status, AdminAuthStatus.authenticated);
      expect(viewModel.errorMessage, isNull);
    });

    test('surfaces the UC-18 message for bad credentials', () async {
      final viewModel = AdminAuthViewModel(
        InMemoryAdminAuthRepository(
          admins: const {
            'admin@example.com': (
              password: 'Secret1!',
              role: AdminRole.superAdmin,
              isActive: true,
            ),
          },
        ),
      );

      final result = await viewModel.signIn(
        email: 'admin@example.com',
        password: 'wrong',
      );

      expect(result, isFalse);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.errorMessage, AdminAuthMessages.invalidCredentials);
    });

    test('rejects empty input without calling the repository', () async {
      final viewModel = AdminAuthViewModel(InMemoryAdminAuthRepository());

      final result = await viewModel.signIn(email: '   ', password: '');

      expect(result, isFalse);
      expect(viewModel.errorMessage, AdminAuthMessages.invalidCredentials);
    });

    test('signOut ends the session', () async {
      final viewModel = AdminAuthViewModel(
        InMemoryAdminAuthRepository(
          admins: const {
            'admin@example.com': (
              password: 'Secret1!',
              role: AdminRole.superAdmin,
              isActive: true,
            ),
          },
        ),
      );
      await viewModel.signIn(
        email: 'admin@example.com',
        password: 'Secret1!',
      );

      final result = await viewModel.signOut();

      expect(result, isTrue);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.status, AdminAuthStatus.unauthenticated);
    });

    test('reports failure so the UI can offer a retry', () async {
      final viewModel = AdminAuthViewModel(
        _FailingSignOutAdminAuthRepository(),
      );
      await viewModel.signIn(
        email: 'admin@example.com',
        password: 'Secret1!',
      );

      final result = await viewModel.signOut();

      expect(result, isFalse);
      expect(viewModel.errorMessage, 'Logout failed. Please try again.');
      // The session must survive a failed logout rather than silently drop.
      expect(viewModel.isAuthenticated, isTrue);
    });
  });
}
