import '../models/admin_role.dart';
import '../models/admin_user.dart';

/// Authentication for the admin portal.
///
/// UC-18 requires the admin session to be separate from the parent/child
/// session, so this deliberately does not reuse [AuthRepository]. Signing in
/// here never grants parent/child access, and signing in as a parent never
/// grants admin access.
abstract class AdminAuthRepository {
  Future<AdminUser?> currentAdmin();

  Future<AdminUser> signIn({
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

  /// Distinct from [notAnAdmin]: the account is a known admin whose access has
  /// been switched off, so telling them to contact someone is more use than
  /// implying they never had rights.
  static const suspended =
      'This admin account has been deactivated. Contact a super admin.';
}

/// Demo-mode admin auth used when the app runs with `USE_FIREBASE=false`.
///
/// Seeded with one admin per role so the portal — and the differences between
/// roles — can be exercised without a Firebase project.
class InMemoryAdminAuthRepository implements AdminAuthRepository {
  InMemoryAdminAuthRepository({
    Map<String, ({String password, AdminRole role, bool isActive})>? admins,
  }) : _admins = {
          for (final entry in (admins ?? _defaultAdmins).entries)
            entry.key.trim().toLowerCase(): entry.value,
        };

  static const _defaultAdmins =
      <String, ({String password, AdminRole role, bool isActive})>{
    'admin@littlelearners.local': (
      password: 'Admin@123',
      role: AdminRole.superAdmin,
      isActive: true,
    ),
    'content@littlelearners.local': (
      password: 'Admin@123',
      role: AdminRole.contentAdmin,
      isActive: true,
    ),
    'viewer@littlelearners.local': (
      password: 'Admin@123',
      role: AdminRole.analyticsViewer,
      isActive: true,
    ),
  };

  final Map<String, ({String password, AdminRole role, bool isActive})> _admins;
  AdminUser? _currentAdmin;

  @override
  Future<AdminUser?> currentAdmin() async => _currentAdmin;

  @override
  Future<AdminUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final record = _admins[normalizedEmail];

    if (record == null || record.password != password) {
      throw const AdminAuthException(AdminAuthMessages.invalidCredentials);
    }

    if (!record.isActive) {
      throw const AdminAuthException(AdminAuthMessages.suspended);
    }

    final admin = AdminUser(
      uid: 'admin-${normalizedEmail.hashCode}',
      email: normalizedEmail,
      role: record.role,
      createdAt: DateTime.now(),
    );
    _currentAdmin = admin;
    return admin;
  }

  @override
  Future<void> signOut() async {
    _currentAdmin = null;
  }
}
