import '../models/parent_account.dart';
import '../services/firebase/firebase_auth_service.dart';
import '../services/firebase/parent_firestore_service.dart';
import '../services/firebase/password_reset_service.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({
    required ParentAuthRemoteDataSource authService,
    required ParentRemoteDataSource parentRemoteDataSource,
    required PasswordResetRemoteDataSource passwordResetRemoteDataSource,
  })  : _authService = authService,
        _parentRemoteDataSource = parentRemoteDataSource,
        _passwordResetRemoteDataSource = passwordResetRemoteDataSource;

  final ParentAuthRemoteDataSource _authService;
  final ParentRemoteDataSource _parentRemoteDataSource;
  final PasswordResetRemoteDataSource _passwordResetRemoteDataSource;

  @override
  Future<ParentAccount?> currentParent() async {
    final parent = _authService.currentParent();
    if (parent == null) return null;

    return _parentRemoteDataSource.ensureParentDocument(parent);
  }

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    final parent = await _authService.signIn(
      email: email,
      password: password,
    );
    return _parentRemoteDataSource.ensureParentDocument(parent);
  }

  @override
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  }) async {
    final parent = await _authService.signUp(
      email: email,
      password: password,
    );
    return _parentRemoteDataSource.ensureParentDocument(parent);
  }

  @override
  Future<ParentAccount> signInWithGoogle() async {
    final parent = await _authService.signInWithGoogle();
    if (parent == null) {
      throw const GoogleSignInCancelled();
    }
    return _parentRemoteDataSource.ensureParentDocument(parent);
  }

  @override
  Future<void> requestPasswordResetOtp(String email) {
    return _passwordResetRemoteDataSource.requestOtp(email);
  }

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) {
    return _passwordResetRemoteDataSource.verifyOtp(email: email, otp: otp);
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) {
    return _passwordResetRemoteDataSource.confirmReset(
      email: email,
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> signOut() {
    return _authService.signOut();
  }
}
