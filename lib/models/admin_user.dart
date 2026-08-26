import 'admin_role.dart';

/// An admin account, backed by `adminUsers/{uid}` in Firestore.
///
/// Kept separate from [ParentAccount] on purpose: a back-office user is not a
/// family, and granting admin should not require inventing a parent document
/// with children attached to it.
class AdminUser {
  const AdminUser({
    required this.uid,
    required this.email,
    required this.role,
    this.isActive = true,
    this.displayName,
    this.createdAt,
  });

  /// Firebase Auth UID. Also the document id.
  final String uid;
  final String email;
  final AdminRole role;

  /// Lets an account be suspended without deleting it, keeping the audit
  /// trail of who had access.
  final bool isActive;

  final String? displayName;
  final DateTime? createdAt;

  bool get canManageContent => isActive && role.canManageContent;
  bool get canManageMedia => isActive && role.canManageMedia;
  bool get canViewStatistics => isActive && role.canViewStatistics;
  bool get canViewParentAccounts => isActive && role.canViewParentAccounts;

  /// True when the account may reach the portal at all.
  bool get canSignIn => isActive;

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email;
  }

  AdminUser copyWith({
    String? email,
    AdminRole? role,
    bool? isActive,
    String? displayName,
    DateTime? createdAt,
  }) {
    return AdminUser(
      uid: uid,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
