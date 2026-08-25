/// Roles an admin account can hold.
///
/// The `name` of each value is the **role id** stored in Firestore at
/// `adminUsers/{uid}.role`, so these strings are part of the data contract —
/// renaming a value silently demotes every account already carrying it.
enum AdminRole {
  /// Full access, including the parent account list.
  superAdmin,

  /// Authors and publishes learning content and media. Cannot see parent
  /// accounts, which are personal data an author does not need.
  contentAdmin,

  /// Read-only access to usage statistics.
  analyticsViewer;

  static const fallback = AdminRole.contentAdmin;

  /// Resolves a stored role id, tolerating case and stray whitespace.
  ///
  /// Returns null rather than guessing when the value is absent or unknown, so
  /// a typo in the console denies access instead of silently granting some.
  static AdminRole? fromId(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final role in AdminRole.values) {
      if (role.name.toLowerCase() == normalized) return role;
    }
    return null;
  }

  /// The id written to Firestore.
  String get id => name;

  /// May create, edit, delete and publish modules, levels and quizzes.
  bool get canManageContent =>
      this == AdminRole.superAdmin || this == AdminRole.contentAdmin;

  /// May upload and delete media assets.
  bool get canManageMedia => canManageContent;

  /// May read system-wide usage statistics.
  bool get canViewStatistics => true;

  /// May list registered parent accounts.
  ///
  /// Deliberately narrower than the rest: the list carries parent emails, so
  /// only a super admin sees it.
  bool get canViewParentAccounts => this == AdminRole.superAdmin;

  String get label => switch (this) {
        AdminRole.superAdmin => 'Super admin',
        AdminRole.contentAdmin => 'Content admin',
        AdminRole.analyticsViewer => 'Analytics viewer',
      };

  String get description => switch (this) {
        AdminRole.superAdmin =>
          'Full access, including the parent account list.',
        AdminRole.contentAdmin =>
          'Manages learning content and media, and reads statistics.',
        AdminRole.analyticsViewer => 'Reads statistics only.',
      };
}
