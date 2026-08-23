import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/parent_account.dart';
import '../../repositories/auth_repository.dart';
import '../auth/google_identity_service.dart';

abstract class ParentAuthRemoteDataSource {
  ParentAccount? currentParent();

  Future<ParentAccount> signIn({
    required String email,
    required String password,
  });

  Future<ParentAccount> signUp({
    required String email,
    required String password,
  });

  /// Returns null when the parent dismisses the Google account chooser.
  Future<ParentAccount?> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

class FirebaseAuthService implements ParentAuthRemoteDataSource {
  FirebaseAuthService({
    FirebaseAuth? auth,
    GoogleIdentityService? googleIdentityService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleIdentityService =
            googleIdentityService ?? PluginGoogleIdentityService();

  final FirebaseAuth _auth;
  final GoogleIdentityService _googleIdentityService;

  @override
  ParentAccount? currentParent() {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;
    return _toParentAccount(user);
  }

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return _toParentAccount(credential.user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthMessageFor(error));
    }
  }

  @override
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return _toParentAccount(credential.user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthMessageFor(error));
    }
  }

  @override
  Future<ParentAccount?> signInWithGoogle() async {
    final idToken = await _googleIdentityService.requestIdToken();
    if (idToken == null) return null;

    try {
      final credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return _toParentAccount(credential.user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthMessageFor(error));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthMessageFor(error));
    }
  }

  @override
  Future<void> signOut() async {
    // Clear Google too, otherwise the next "Continue with Google" silently
    // re-uses the account the parent just left.
    await _googleIdentityService.signOut();
    await _auth.signOut();
  }

  ParentAccount _toParentAccount(User? user) {
    if (user == null || user.email == null) {
      throw const AuthException('No authenticated parent found.');
    }
    return ParentAccount(
      id: user.uid,
      email: user.email!.trim().toLowerCase(),
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }
}

@visibleForTesting
String firebaseAuthMessageFor(FirebaseAuthException error) {
  final message = error.message ?? '';
  switch (error.code) {
    case 'configuration-not-found':
    case 'operation-not-allowed':
      return _firebaseSetupMessage;
    case 'internal-error':
      if (message.contains('CONFIGURATION_NOT_FOUND')) {
        return _firebaseSetupMessage;
      }
      return message.isEmpty
          ? 'Authentication failed. Please try again.'
          : message;
    case 'email-already-in-use':
      return 'An account already exists for this email.';
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'user-disabled':
      return 'This parent account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email or password is incorrect.';
    case 'weak-password':
      return 'Use a stronger password.';
    case 'account-exists-with-different-credential':
      return 'This email already has a password account. Sign in with your '
          'password, then link Google from account settings.';
    default:
      return message.isEmpty
          ? 'Authentication failed. Please try again.'
          : message;
  }
}

const _firebaseSetupMessage =
    'This sign-in method is not enabled yet. In Firebase Console, open '
    'Authentication > Sign-in method and enable Email/Password and Google. '
    'Google also needs this app\'s SHA-1 and SHA-256 fingerprints registered.';
