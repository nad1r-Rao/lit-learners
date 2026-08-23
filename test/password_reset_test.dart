import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';

void main() {
  group('AuthViewModel password reset', () {
    test('asks the repository to mail a link and confirms in place', () async {
      final repository = InMemoryAuthRepository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);

      expect(await viewModel.sendPasswordReset('Parent@Example.com '), isTrue);

      expect(repository.passwordResetEmails, ['parent@example.com']);
      expect(viewModel.infoMessage, contains('Reset link sent'));
      expect(viewModel.errorMessage, isNull);
    });

    test('rejects a malformed email without calling the backend', () async {
      final repository = InMemoryAuthRepository();
      final viewModel = AuthViewModel(repository);

      expect(await viewModel.sendPasswordReset('not-an-email'), isFalse);

      expect(repository.passwordResetEmails, isEmpty);
      expect(viewModel.errorMessage, 'Enter a valid email address.');
    });

    test('surfaces an unknown account as an error', () async {
      final viewModel = AuthViewModel(InMemoryAuthRepository());

      expect(await viewModel.sendPasswordReset('nobody@example.com'), isFalse);

      expect(viewModel.errorMessage, 'No account found for this email.');
      expect(viewModel.infoMessage, isNull);
    });

    test('clears a stale message when the screen is reopened', () async {
      final repository = InMemoryAuthRepository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);
      await viewModel.sendPasswordReset('parent@example.com');

      viewModel.resetPasswordFlow();

      expect(viewModel.infoMessage, isNull);
      expect(viewModel.errorMessage, isNull);
    });
  });

  group('AuthViewModel Google sign-in', () {
    test('signs in with Google', () async {
      final viewModel = AuthViewModel(InMemoryAuthRepository());

      expect(await viewModel.signInWithGoogle(), isTrue);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('stays quiet when the parent dismisses the chooser', () async {
      final viewModel = AuthViewModel(_CancellingAuthRepository());

      expect(await viewModel.signInWithGoogle(), isFalse);
      expect(viewModel.isAuthenticated, isFalse);
      // Backing out on purpose is not something to shout about.
      expect(viewModel.errorMessage, isNull);
    });
  });
}

class _CancellingAuthRepository extends InMemoryAuthRepository {
  @override
  Future<Never> signInWithGoogle() async => throw const GoogleSignInCancelled();
}
