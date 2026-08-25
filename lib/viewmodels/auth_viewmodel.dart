import 'package:flutter/foundation.dart';

import '../core/utils/validators.dart';
import '../models/parent_account.dart';
import '../repositories/auth_repository.dart';

enum AuthFlowStatus {
  idle,
  loading,
  authenticated,
  unauthenticated,
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authRepository);

  final AuthRepository _authRepository;

  ParentAccount? _parent;
  AuthFlowStatus _status = AuthFlowStatus.idle;
  String? _errorMessage;
  String? _infoMessage;

  ParentAccount? get parent => _parent;
  AuthFlowStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  bool get isLoading => _status == AuthFlowStatus.loading;
  bool get isAuthenticated => _parent != null;

  Future<void> loadCurrentParent() async {
    _status = AuthFlowStatus.loading;
    notifyListeners();

    _parent = await _authRepository.currentParent();
    _status = _parent == null
        ? AuthFlowStatus.unauthenticated
        : AuthFlowStatus.authenticated;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final validationError =
        Validators.email(email) ?? Validators.loginPassword(password);
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    return _runAuthAction(() {
      return _authRepository.signIn(email: email, password: password);
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    final validationError = _validateEmailAndPassword(email, password);
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    return _runAuthAction(() {
      return _authRepository.signUp(email: email, password: password);
    });
  }

  Future<bool> signInWithGoogle() async {
    _status = AuthFlowStatus.loading;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      _parent = await _authRepository.signInWithGoogle();
      _status = AuthFlowStatus.authenticated;
      notifyListeners();
      return true;
    } on GoogleSignInCancelled {
      // Backing out of the chooser is not an error worth showing.
      _status = _parent == null
          ? AuthFlowStatus.unauthenticated
          : AuthFlowStatus.authenticated;
      notifyListeners();
      return false;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    }
  }

  /// Mails a reset link to [email]. Firebase takes it from there — the link
  /// opens Firebase's own page, so the app never handles the new password.
  Future<bool> sendPasswordReset(String email) async {
    final emailError = Validators.email(email);
    if (emailError != null) {
      _setError(emailError);
      return false;
    }

    _status = AuthFlowStatus.loading;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();
    try {
      await _authRepository.sendPasswordReset(normalizedEmail);
      _infoMessage = 'Reset link sent to $normalizedEmail. Open it to choose '
          'a new password, and check your spam folder if it has not arrived.';
      _status = _parent == null
          ? AuthFlowStatus.unauthenticated
          : AuthFlowStatus.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    }
  }

  /// Clears any message left over from an earlier visit to the reset screen.
  void resetPasswordFlow() {
    _errorMessage = null;
    _infoMessage = null;
    _status = _parent == null
        ? AuthFlowStatus.unauthenticated
        : AuthFlowStatus.authenticated;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _parent = null;
    _status = AuthFlowStatus.unauthenticated;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  Future<bool> _runAuthAction(
    Future<ParentAccount> Function() action,
  ) async {
    _status = AuthFlowStatus.loading;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      _parent = await action();
      _status = AuthFlowStatus.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    }
  }

  String? _validateEmailAndPassword(String email, String password) {
    return Validators.email(email) ?? Validators.password(password);
  }

  void _setError(String message) {
    _errorMessage = message;
    _infoMessage = null;
    _status = _parent == null
        ? AuthFlowStatus.unauthenticated
        : AuthFlowStatus.authenticated;
    notifyListeners();
  }
}
