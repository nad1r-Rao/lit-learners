import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:little_learners/models/onboarding.dart';
import 'package:little_learners/models/parent_account.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/repositories/firebase_auth_repository.dart';
import 'package:little_learners/services/firebase/firebase_auth_service.dart';
import 'package:little_learners/services/firebase/parent_firestore_service.dart';
import 'package:little_learners/services/firebase/password_reset_service.dart';

void main() {
  group('FirebaseAuthRepository', () {
    test('ensures the parent document after signup', () async {
      final account = _parentAccount('parent-1');
      final authService =
          _FakeParentAuthRemoteDataSource(signUpParent: account);
      final parentRemoteDataSource = _FakeParentRemoteDataSource();
      final repository = FirebaseAuthRepository(
        authService: authService,
        parentRemoteDataSource: parentRemoteDataSource,
        passwordResetRemoteDataSource: _FakePasswordResetRemoteDataSource(),
      );

      final created = await repository.signUp(
        email: account.email,
        password: 'Strong1!',
      );

      expect(created.id, account.id);
      expect(parentRemoteDataSource.ensuredParentIds, [account.id]);
    });

    test('returns the parent role loaded from the parent document', () async {
      final account = _parentAccount('parent-3');
      final authService =
          _FakeParentAuthRemoteDataSource(signInParent: account);
      final parentRemoteDataSource = _FakeParentRemoteDataSource(
        role: ParentRole.admin,
      );
      final repository = FirebaseAuthRepository(
        authService: authService,
        parentRemoteDataSource: parentRemoteDataSource,
        passwordResetRemoteDataSource: _FakePasswordResetRemoteDataSource(),
      );

      final signedIn = await repository.signIn(
        email: account.email,
        password: 'Strong1!',
      );

      expect(signedIn.role, ParentRole.admin);
      expect(signedIn.canManageAdminContent, isTrue);
    });

    test('ensures the parent document for an existing session', () async {
      final account = _parentAccount('parent-2');
      final authService = _FakeParentAuthRemoteDataSource(current: account);
      final parentRemoteDataSource = _FakeParentRemoteDataSource();
      final repository = FirebaseAuthRepository(
        authService: authService,
        parentRemoteDataSource: parentRemoteDataSource,
        passwordResetRemoteDataSource: _FakePasswordResetRemoteDataSource(),
      );

      final currentParent = await repository.currentParent();

      expect(currentParent?.id, account.id);
      expect(parentRemoteDataSource.ensuredParentIds, [account.id]);
    });

    test('signs in with Google through the parent document', () async {
      final account = _parentAccount('parent-google');
      final authService =
          _FakeParentAuthRemoteDataSource(googleParent: account);
      final parentRemoteDataSource = _FakeParentRemoteDataSource();
      final repository = FirebaseAuthRepository(
        authService: authService,
        parentRemoteDataSource: parentRemoteDataSource,
        passwordResetRemoteDataSource: _FakePasswordResetRemoteDataSource(),
      );

      final signedIn = await repository.signInWithGoogle();

      expect(signedIn.id, account.id);
      expect(parentRemoteDataSource.ensuredParentIds, [account.id]);
    });

    test('reports a cancelled Google chooser as its own exception', () async {
      // Null from the data source means the parent dismissed the sheet; the
      // UI has to tell that apart from a real failure.
      final repository = FirebaseAuthRepository(
        authService: _FakeParentAuthRemoteDataSource(),
        parentRemoteDataSource: _FakeParentRemoteDataSource(),
        passwordResetRemoteDataSource: _FakePasswordResetRemoteDataSource(),
      );

      expect(
        repository.signInWithGoogle(),
        throwsA(isA<GoogleSignInCancelled>()),
      );
    });

    test('walks the OTP reset through to a stored password', () async {
      final authService = _FakeParentAuthRemoteDataSource();
      final passwordReset = _FakePasswordResetRemoteDataSource();
      final repository = FirebaseAuthRepository(
        authService: authService,
        parentRemoteDataSource: _FakeParentRemoteDataSource(),
        passwordResetRemoteDataSource: passwordReset,
      );

      await repository.requestPasswordResetOtp('parent@example.com');
      final token = await repository.verifyPasswordResetOtp(
        email: 'parent@example.com',
        otp: '123456',
      );
      await repository.confirmPasswordReset(
        email: 'parent@example.com',
        resetToken: token,
        newPassword: 'Stronger1!',
      );
      await repository.signOut();

      expect(passwordReset.requestedEmail, 'parent@example.com');
      expect(passwordReset.verifiedOtp, '123456');
      expect(passwordReset.storedPassword, 'Stronger1!');
      expect(authService.didSignOut, isTrue);
    });

    test('maps Firebase auth setup errors to an actionable message', () {
      final message = firebaseAuthMessageFor(
        FirebaseAuthException(
          code: 'internal-error',
          message:
              'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]',
        ),
      );

      expect(message, contains('Authentication > Sign-in method'));
    });
  });
}

ParentAccount _parentAccount(String id) {
  return ParentAccount(
    id: id,
    email: '$id@example.com',
    createdAt: DateTime(2026),
  );
}

class _FakeParentAuthRemoteDataSource implements ParentAuthRemoteDataSource {
  _FakeParentAuthRemoteDataSource({
    this.current,
    ParentAccount? signInParent,
    ParentAccount? signUpParent,
    ParentAccount? googleParent,
  })  : _signInParent = signInParent,
        _signUpParent = signUpParent,
        _googleParent = googleParent;

  ParentAccount? current;
  final ParentAccount? _signInParent;
  final ParentAccount? _signUpParent;
  final ParentAccount? _googleParent;
  bool didSignOut = false;

  @override
  ParentAccount? currentParent() => current;

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    return _signInParent ?? _parentAccount('signed-in-parent');
  }

  @override
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  }) async {
    return _signUpParent ?? _parentAccount('signed-up-parent');
  }

  @override
  Future<ParentAccount?> signInWithGoogle() async => _googleParent;

  @override
  Future<void> signOut() async {
    didSignOut = true;
    current = null;
  }
}

class _FakeParentRemoteDataSource implements ParentRemoteDataSource {
  _FakeParentRemoteDataSource({this.role = ParentRole.parent});

  final ParentRole role;
  final List<String> ensuredParentIds = [];

  @override
  Future<ParentAccount> ensureParentDocument(ParentAccount parent) async {
    ensuredParentIds.add(parent.id);
    return parent.copyWith(role: role);
  }

  @override
  Future<ParentOnboardingState> completeManual(String parentId) {
    throw UnimplementedError();
  }

  @override
  Future<ParentOnboardingState> getOnboardingState(String parentId) {
    throw UnimplementedError();
  }

  @override
  Future<ParentOnboardingState> updateManualPage({
    required String parentId,
    required int pageIndex,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ParentOnboardingState> updateReadinessResult({
    required String parentId,
    required int score,
    required bool passed,
  }) {
    throw UnimplementedError();
  }
}

class _FakePasswordResetRemoteDataSource
    implements PasswordResetRemoteDataSource {
  String? requestedEmail;
  String? verifiedOtp;
  String? storedPassword;

  @override
  Future<void> requestOtp(String email) async {
    requestedEmail = email;
  }

  @override
  Future<String> verifyOtp({
    required String email,
    required String otp,
  }) async {
    verifiedOtp = otp;
    return 'reset-token';
  }

  @override
  Future<void> confirmReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    if (resetToken != 'reset-token') {
      throw const AuthException('Verify the code again before continuing.');
    }
    storedPassword = newPassword;
  }
}
