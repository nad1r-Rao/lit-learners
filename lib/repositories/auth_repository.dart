import 'dart:math';

import '../models/parent_account.dart';

abstract class AuthRepository {
  Future<ParentAccount?> currentParent();
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  });
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  });
  Future<ParentAccount> signInWithGoogle();

  /// Step one of the reset: mail a short code to [email]. Replaces the old
  /// reset *link*, which relied on the parent leaving the app and coming back
  /// through a deep link.
  Future<void> requestPasswordResetOtp(String email);

  /// Step two: exchange a correct code for a short-lived token that authorises
  /// exactly one password change. Nothing else in the app accepts this token.
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  });

  /// Step three: store [newPassword] against the account the token was issued
  /// for. The token is spent whether or not the change succeeds.
  Future<void> confirmPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  });

  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the parent closes the Google account chooser. Separate from a
/// plain [AuthException] so the UI can stay quiet instead of showing an error
/// for something the parent did deliberately.
class GoogleSignInCancelled extends AuthException {
  const GoogleSignInCancelled() : super('Google sign-in was cancelled.');
}

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({
    Set<String> adminEmails = const {'admin@littlelearners.local'},
    Random? random,
  })  : _adminEmails = adminEmails
            .map((email) => email.trim().toLowerCase())
            .where((email) => email.isNotEmpty)
            .toSet(),
        _random = random ?? Random();

  final Map<String, _StoredParent> _parentsByEmail = {};
  final Map<String, _StoredOtp> _otpsByEmail = {};
  final Set<String> _adminEmails;
  final Random _random;
  ParentAccount? _currentParent;

  /// The code the fake "mailer" would have sent, so a widget test or a local
  /// run without Firebase can walk the whole reset flow.
  String? lastOtpFor(String email) =>
      _otpsByEmail[email.trim().toLowerCase()]?.otp;

  @override
  Future<ParentAccount?> currentParent() async => _currentParent;

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final storedParent = _parentsByEmail[normalizedEmail];

    if (storedParent == null || storedParent.password != password) {
      throw const AuthException('Email or password is incorrect.');
    }

    _currentParent = storedParent.account;
    return storedParent.account;
  }

  @override
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_parentsByEmail.containsKey(normalizedEmail)) {
      throw const AuthException('An account already exists for this email.');
    }

    final account = ParentAccount(
      id: 'parent-${DateTime.now().microsecondsSinceEpoch}',
      email: normalizedEmail,
      createdAt: DateTime.now(),
      role: _roleFor(normalizedEmail),
    );
    _parentsByEmail[normalizedEmail] = _StoredParent(
      account: account,
      password: password,
    );
    _currentParent = account;
    return account;
  }

  @override
  Future<ParentAccount> signInWithGoogle() async {
    const normalizedEmail = 'google.parent@littlelearners.local';
    final stored = _parentsByEmail[normalizedEmail];
    if (stored != null) {
      _currentParent = stored.account;
      return stored.account;
    }

    final account = ParentAccount(
      id: 'parent-google-${DateTime.now().microsecondsSinceEpoch}',
      email: normalizedEmail,
      createdAt: DateTime.now(),
      role: _roleFor(normalizedEmail),
    );
    _parentsByEmail[normalizedEmail] = _StoredParent(
      account: account,
      password: '',
    );
    _currentParent = account;
    return account;
  }

  @override
  Future<void> requestPasswordResetOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_parentsByEmail.containsKey(normalizedEmail)) {
      throw const AuthException('No account found for this email.');
    }

    _otpsByEmail[normalizedEmail] = _StoredOtp(
      otp: (_random.nextInt(900000) + 100000).toString(),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final stored = _otpsByEmail[normalizedEmail];
    if (stored == null || stored.expiresAt.isBefore(DateTime.now())) {
      throw const AuthException('This code has expired. Request a new one.');
    }
    if (stored.otp != otp.trim()) {
      throw const AuthException('That code is not correct.');
    }

    final token = 'reset-${_random.nextInt(1 << 32)}';
    _otpsByEmail[normalizedEmail] = stored.copyWithToken(token);
    return token;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final stored = _otpsByEmail[normalizedEmail];
    final parent = _parentsByEmail[normalizedEmail];
    if (stored == null ||
        parent == null ||
        stored.resetToken == null ||
        stored.resetToken != resetToken) {
      throw const AuthException('Verify the code again before continuing.');
    }

    _otpsByEmail.remove(normalizedEmail);
    _parentsByEmail[normalizedEmail] = _StoredParent(
      account: parent.account,
      password: newPassword,
    );
  }

  @override
  Future<void> signOut() async {
    _currentParent = null;
  }

  ParentRole _roleFor(String normalizedEmail) {
    return _adminEmails.contains(normalizedEmail)
        ? ParentRole.admin
        : ParentRole.parent;
  }
}

class _StoredParent {
  const _StoredParent({
    required this.account,
    required this.password,
  });

  final ParentAccount account;
  final String password;
}

class _StoredOtp {
  const _StoredOtp({
    required this.otp,
    required this.expiresAt,
    this.resetToken,
  });

  final String otp;
  final DateTime expiresAt;
  final String? resetToken;

  _StoredOtp copyWithToken(String token) => _StoredOtp(
        otp: otp,
        expiresAt: expiresAt,
        resetToken: token,
      );
}
