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

/// Digits in the emailed reset code. Mirrors `OTP_LENGTH` in
/// `functions/index.js`; changing one without the other breaks the flow.
const passwordResetOtpLength = 6;

/// Where the parent is in the three-step OTP reset.
enum PasswordResetStep {
  /// Typing the email the code should go to.
  requestCode,

  /// Typing the six digits that arrived by email.
  verifyCode,

  /// Choosing the password that replaces the old one.
  choosePassword,

  /// Stored. The login screen is the only way forward.
  done,
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authRepository);

  final AuthRepository _authRepository;

  ParentAccount? _parent;
  AuthFlowStatus _status = AuthFlowStatus.idle;
  String? _errorMessage;
  String? _infoMessage;
  PasswordResetStep _resetStep = PasswordResetStep.requestCode;
  String? _resetEmail;
  String? _resetToken;

  ParentAccount? get parent => _parent;
  AuthFlowStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  bool get isLoading => _status == AuthFlowStatus.loading;
  bool get isAuthenticated => _parent != null;
  PasswordResetStep get passwordResetStep => _resetStep;

  /// The address the current code was sent to, for showing back to the parent.
  String? get passwordResetEmail => _resetEmail;

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

  // --- OTP password reset -------------------------------------------------

  /// Sends a six-digit code to [email] and moves the flow to [
  /// PasswordResetStep.verifyCode].
  Future<bool> requestPasswordResetOtp(String email) async {
    final emailError = Validators.email(email);
    if (emailError != null) {
      _setError(emailError);
      return false;
    }

    return _runResetAction(
      () async {
        await _authRepository.requestPasswordResetOtp(email);
        _resetEmail = email.trim().toLowerCase();
        _resetToken = null;
        _resetStep = PasswordResetStep.verifyCode;
        _infoMessage = 'We sent a 6-digit code to $_resetEmail. '
            'It expires in 10 minutes.';
      },
    );
  }

  /// Re-sends a code for the email already entered, without leaving the
  /// verify step.
  Future<bool> resendPasswordResetOtp() async {
    final email = _resetEmail;
    if (email == null) {
      _setError('Enter your email first.');
      return false;
    }

    return _runResetAction(() async {
      await _authRepository.requestPasswordResetOtp(email);
      _resetToken = null;
      _infoMessage = 'A fresh code is on its way to $email.';
    });
  }

  /// Checks [otp] and, when it matches, unlocks the new-password step.
  Future<bool> verifyPasswordResetOtp(String otp) async {
    final email = _resetEmail;
    if (email == null) {
      _setError('Enter your email first.');
      return false;
    }

    final trimmed = otp.trim();
    if (trimmed.length != passwordResetOtpLength ||
        int.tryParse(trimmed) == null) {
      _setError('Enter the $passwordResetOtpLength-digit code from the email.');
      return false;
    }

    return _runResetAction(() async {
      _resetToken = await _authRepository.verifyPasswordResetOtp(
        email: email,
        otp: trimmed,
      );
      _resetStep = PasswordResetStep.choosePassword;
      _infoMessage = 'Code confirmed. Choose a new password.';
    });
  }

  /// Stores [newPassword] against the account the code was sent to.
  Future<bool> confirmPasswordReset({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final email = _resetEmail;
    final token = _resetToken;
    if (email == null || token == null) {
      _setError('Verify the code again before continuing.');
      return false;
    }

    final passwordError = Validators.password(newPassword);
    if (passwordError != null) {
      _setError(passwordError);
      return false;
    }
    if (newPassword != confirmPassword) {
      _setError('Both passwords must match.');
      return false;
    }

    return _runResetAction(() async {
      await _authRepository.confirmPasswordReset(
        email: email,
        resetToken: token,
        newPassword: newPassword,
      );
      _resetToken = null;
      _resetStep = PasswordResetStep.done;
      _infoMessage = 'Password updated. Sign in with your new password.';
    });
  }

  /// Drops any half-finished reset, e.g. when the parent leaves the screen.
  void resetPasswordFlow() {
    _resetStep = PasswordResetStep.requestCode;
    _resetEmail = null;
    _resetToken = null;
    _errorMessage = null;
    _infoMessage = null;
    _status = _parent == null
        ? AuthFlowStatus.unauthenticated
        : AuthFlowStatus.authenticated;
    notifyListeners();
  }

  /// Steps back to the email field so a typo can be corrected.
  void editPasswordResetEmail() {
    _resetStep = PasswordResetStep.requestCode;
    _resetToken = null;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  Future<bool> _runResetAction(Future<void> Function() action) async {
    _status = AuthFlowStatus.loading;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await action();
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

  Future<void> signOut() async {
    await _authRepository.signOut();
    _parent = null;
    _status = AuthFlowStatus.unauthenticated;
    _errorMessage = null;
    _infoMessage = null;
    _resetStep = PasswordResetStep.requestCode;
    _resetEmail = null;
    _resetToken = null;
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
