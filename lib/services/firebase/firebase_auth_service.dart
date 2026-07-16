import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/parent_account.dart';
import '../../repositories/auth_repository.dart';

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

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

class FirebaseAuthService implements ParentAuthRemoteDataSource {
  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

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
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthMessageFor(error));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

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
    default:
      return message.isEmpty
          ? 'Authentication failed. Please try again.'
          : message;
  }
}

const _firebaseSetupMessage =
    'Firebase Email/Password sign-in is not enabled yet. In Firebase Console, '
    'open Authentication > Sign-in method and enable Email/Password.';
