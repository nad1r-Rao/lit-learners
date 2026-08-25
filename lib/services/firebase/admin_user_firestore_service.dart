import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/admin_role.dart';
import '../../models/admin_user.dart';

/// Resolves who is an admin.
///
/// Source of truth is `adminUsers/{uid}`. Granting access is therefore one
/// document written from the Firebase console — no Cloud Function, no Admin
/// SDK, no custom claims tooling.
///
/// Schema:
/// ```
/// adminUsers/{uid}
///   email:       string
///   role:        'superAdmin' | 'contentAdmin' | 'analyticsViewer'
///   isActive:    bool
///   displayName: string   (optional)
///   createdAt:   timestamp (optional)
/// ```
abstract class AdminUserRemoteDataSource {
  /// Returns null when the account is not an admin.
  Future<AdminUser?> findAdmin({required String uid, required String email});
}

class AdminUserFirestoreService implements AdminUserRemoteDataSource {
  const AdminUserFirestoreService({
    required FirebaseFirestore firestore,
    this.allowLegacyParentRole = true,
  }) : _firestore = firestore;

  static const adminUsersCollection = 'adminUsers';
  static const parentsCollection = 'parents';

  final FirebaseFirestore _firestore;

  /// Also accept the older `parents/{uid}.role == 'admin'` marker.
  ///
  /// Keeps accounts promoted before `adminUsers` existed working. Turn off
  /// once every admin has been migrated.
  final bool allowLegacyParentRole;

  @override
  Future<AdminUser?> findAdmin({
    required String uid,
    required String email,
  }) async {
    final doc =
        await _firestore.collection(adminUsersCollection).doc(uid).get();

    if (doc.exists) {
      return _fromAdminDoc(uid: uid, email: email, data: doc.data() ?? {});
    }

    if (!allowLegacyParentRole) return null;
    return _legacyAdminFromParentDoc(uid: uid, email: email);
  }

  AdminUser? _fromAdminDoc({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
  }) {
    // A document with no usable role is treated as no access rather than
    // defaulting to something permissive - a typo in the console should lock
    // the account out, not hand it a role nobody chose.
    final role = AdminRole.fromId(data['role']);
    if (role == null) return null;

    // Absent isActive means active; only an explicit false suspends.
    final isActive = data['isActive'] as bool? ?? true;

    return AdminUser(
      uid: uid,
      email: (data['email'] as String?)?.trim().isNotEmpty == true
          ? (data['email'] as String).trim()
          : email,
      role: role,
      isActive: isActive,
      displayName: (data['displayName'] as String?)?.trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<AdminUser?> _legacyAdminFromParentDoc({
    required String uid,
    required String email,
  }) async {
    final doc = await _firestore.collection(parentsCollection).doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? const <String, dynamic>{};
    final isLegacyAdmin = data['isAdmin'] == true ||
        (data['role'] is String &&
            (data['role'] as String).trim().toLowerCase() == 'admin');
    if (!isLegacyAdmin) return null;

    // Legacy markers carry no granularity, so they map to the role that can do
    // the content work they were created for - not to superAdmin.
    return AdminUser(
      uid: uid,
      email: (data['email'] as String?) ?? email,
      role: AdminRole.fallback,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
