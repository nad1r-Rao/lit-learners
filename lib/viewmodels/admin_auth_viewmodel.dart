import 'package:flutter/foundation.dart';

import '../models/parent_account.dart';
import '../repositories/admin_auth_repository.dart';

enum AdminAuthStatus { idle, loading, authenticated, unauthenticated }

/// Drives the admin portal session, kept deliberately separate from
/// [AuthViewModel] so an admin login never authenticates a parent (UC-18).
class AdminAuthViewModel extends ChangeNotifier {
  AdminAuthViewModel(this._adminAuthRepository);

  final AdminAuthRepository _adminAuthRepository;

  ParentAccount? _admin;
  AdminAuthStatus _status = AdminAuthStatus.idle;
  String? _errorMessage;

  ParentAccount? get admin => _admin;
  AdminAuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AdminAuthStatus.loading;
  bool get isAuthenticated => _admin != null;

  Future<void> loadCurrentAdmin() async {
    _status = AdminAuthStatus.loading;
    notifyListeners();

    try {
      _admin = await _adminAuthRepository.currentAdmin();
    } on AdminAuthException {
      _admin = null;
    }

    _status = _admin == null
        ? AdminAuthStatus.unauthenticated
        : AdminAuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    // Empty fields reuse the credential message so the form never reveals
    // which half was wrong.
    if (email.trim().isEmpty || password.isEmpty) {
      _setError(AdminAuthMessages.invalidCredentials);
      return false;
    }

    _status = AdminAuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _admin = await _adminAuthRepository.signIn(
        email: email,
        password: password,
      );
      _status = AdminAuthStatus.authenticated;
      notifyListeners();
      return true;
    } on AdminAuthException catch (error) {
      _setError(error.message);
      return false;
    }
  }

  /// UC-20: terminates the admin session.
  ///
  /// Returns false and surfaces an error so the UI can offer a retry.
  Future<bool> signOut() async {
    _status = AdminAuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _adminAuthRepository.signOut();
      _admin = null;
      _status = AdminAuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on Exception {
      _setError('Logout failed. Please try again.');
      return false;
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = _admin == null
        ? AdminAuthStatus.unauthenticated
        : AdminAuthStatus.authenticated;
    notifyListeners();
  }
}
