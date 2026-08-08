import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';

void main() {
  group('InMemoryAuthRepository OTP reset', () {
    test('stores the new password against the account that was verified',
        () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');

      await repository.requestPasswordResetOtp('parent@example.com');
      final otp = repository.lastOtpFor('parent@example.com')!;
      final token = await repository.verifyPasswordResetOtp(
        email: 'parent@example.com',
        otp: otp,
      );
      await repository.confirmPasswordReset(
        email: 'parent@example.com',
        resetToken: token,
        newPassword: 'Brand1New!',
      );

      final signedIn = await repository.signIn(
        email: 'parent@example.com',
        password: 'Brand1New!',
      );

      expect(signedIn.email, 'parent@example.com');
      expect(
        repository.signIn(email: 'parent@example.com', password: 'Old1!aaa'),
        throwsA(isA<AuthException>()),
      );
    });

    test('refuses a code that does not match', () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      await repository.requestPasswordResetOtp('parent@example.com');

      expect(
        repository.verifyPasswordResetOtp(
          email: 'parent@example.com',
          otp: '000000',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('refuses a reset that skipped verification', () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      await repository.requestPasswordResetOtp('parent@example.com');

      expect(
        repository.confirmPasswordReset(
          email: 'parent@example.com',
          resetToken: 'made-up',
          newPassword: 'Brand1New!',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('spends the token so it cannot reset a second time', () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      await repository.requestPasswordResetOtp('parent@example.com');
      final token = await repository.verifyPasswordResetOtp(
        email: 'parent@example.com',
        otp: repository.lastOtpFor('parent@example.com')!,
      );
      await repository.confirmPasswordReset(
        email: 'parent@example.com',
        resetToken: token,
        newPassword: 'Brand1New!',
      );

      expect(
        repository.confirmPasswordReset(
          email: 'parent@example.com',
          resetToken: token,
          newPassword: 'Another1!',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('will not send a code to an address with no account', () async {
      final repository = _repository();

      expect(
        repository.requestPasswordResetOtp('nobody@example.com'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthViewModel password reset flow', () {
    test('walks request, verify and save in order', () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);

      expect(viewModel.passwordResetStep, PasswordResetStep.requestCode);

      expect(
        await viewModel.requestPasswordResetOtp('parent@example.com'),
        isTrue,
      );
      expect(viewModel.passwordResetStep, PasswordResetStep.verifyCode);
      expect(viewModel.passwordResetEmail, 'parent@example.com');

      expect(
        await viewModel.verifyPasswordResetOtp(
          repository.lastOtpFor('parent@example.com')!,
        ),
        isTrue,
      );
      expect(viewModel.passwordResetStep, PasswordResetStep.choosePassword);

      expect(
        await viewModel.confirmPasswordReset(
          newPassword: 'Brand1New!',
          confirmPassword: 'Brand1New!',
        ),
        isTrue,
      );
      expect(viewModel.passwordResetStep, PasswordResetStep.done);
    });

    test('rejects a malformed code without calling the backend', () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);
      await viewModel.requestPasswordResetOtp('parent@example.com');

      expect(await viewModel.verifyPasswordResetOtp('12ab'), isFalse);
      expect(viewModel.errorMessage, contains('6-digit'));
      expect(viewModel.passwordResetStep, PasswordResetStep.verifyCode);
    });

    test('refuses mismatched passwords before writing anything', () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);
      await viewModel.requestPasswordResetOtp('parent@example.com');
      await viewModel.verifyPasswordResetOtp(
        repository.lastOtpFor('parent@example.com')!,
      );

      expect(
        await viewModel.confirmPasswordReset(
          newPassword: 'Brand1New!',
          confirmPassword: 'Different1!',
        ),
        isFalse,
      );
      expect(viewModel.errorMessage, 'Both passwords must match.');
      expect(viewModel.passwordResetStep, PasswordResetStep.choosePassword);
    });

    test('enforces the same password rules as signup', () async {
      final repository = _repository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);
      await viewModel.requestPasswordResetOtp('parent@example.com');
      await viewModel.verifyPasswordResetOtp(
        repository.lastOtpFor('parent@example.com')!,
      );

      expect(
        await viewModel.confirmPasswordReset(
          newPassword: 'weak',
          confirmPassword: 'weak',
        ),
        isFalse,
      );
      expect(viewModel.errorMessage, 'Use at least 8 characters.');
    });

    test('signs in with Google', () async {
      final viewModel = AuthViewModel(_repository());

      expect(await viewModel.signInWithGoogle(), isTrue);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });
  });
}

InMemoryAuthRepository _repository() {
  // Seeded so a failing run reproduces with the same codes.
  return InMemoryAuthRepository(random: Random(7));
}
