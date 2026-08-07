import '../models/parent_account.dart';

/// Authentication for the admin portal.
///
/// UC-18 requires the admin session to be separate from the parent/child
/// session, so this deliberately does not reuse [AuthRepository]. Signing in
/// here never grants parent/child access, and signing in as a parent never
/// grants admin access.
abstract class AdminAuthRepository {
  Future<ParentAccount?> currentAdmin();

  Future<ParentAccount> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class AdminAuthException implements Exception {
  const AdminAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Messages fixed by UC-18's alternative flows.
class AdminAuthMessages {
  const AdminAuthMessages._();

  static const invalidCredentials = 'Invalid Email or Password';
  static const notAnAdmin = 'Access Denied: Admin Rights Required';
}

/// Demo-mode admin auth used when the app runs with `USE_FIREBASE=false`.
///
/// Seeded with a single known admin so the portal is reachable without a
/// Firebase project.
class InMemoryAdminAuthRepository implements AdminAuthRepository {
  InMemoryAdminAuthRepository({
    Map<String, String> adminCredentials = const {
      'admin@littlelearners.local': 'Admin@123',
    },
  }) : _adminCredentials = {
          for (final entry in adminCredentials.entries)
            entry.key.trim().toLowerCase(): entry.value,
        };

  final Map<String, String> _adminCredentials;
  ParentAccount? _currentAdmin;

  @override
  Future<ParentAccount?> currentAdmin() async => _currentAdmin;

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final expectedPassword = _adminCredentials[normalizedEmail];

    if (expectedPassword == null || expectedPassword != password) {
      throw const AdminAuthException(AdminAuthMessages.invalidCredentials);
    }

    final admin = ParentAccount(
      id: 'admin-${normalizedEmail.hashCode}',
      email: normalizedEmail,
      createdAt: DateTime.now(),
      role: ParentRole.admin,
    );
    _currentAdmin = admin;
    return admin;
  }

  @override
  Future<void> signOut() async {
    _currentAdmin = null;
  }
}
