import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/parent_account.dart';
import 'admin_auth_repository.dart';

/// Firebase-backed admin authentication (UC-18).
///
/// Runs against a secondary [FirebaseApp] so the admin's Firebase Auth session
/// is genuinely independent of the parent session on the default app. Without
/// this, signing in as an admin would replace `FirebaseAuth.instance.currentUser`
/// and leak admin identity into the parent/child flow.
class FirebaseAdminAuthRepository implements AdminAuthRepository {
  FirebaseAdminAuthRepository({String adminAppName = 'littleLearnersAdmin'})
      : _adminAppName = adminAppName;

  static const _adminRoleValue = 'admin';

  final String _adminAppName;
  FirebaseApp? _adminApp;

  Future<FirebaseApp> _app() async {
    final existing = _adminApp;
    if (existing != null) return existing;

    // Reuse the instance across hot restarts instead of re-initializing.
    FirebaseApp app;
    try {
      app = Firebase.app(_adminAppName);
    } on FirebaseException {
      app = await Firebase.initializeApp(
        name: _adminAppName,
        options: Firebase.app().options,
      );
    }
    _adminApp = app;
    return app;
  }

  Future<FirebaseAuth> _auth() async => FirebaseAuth.instanceFor(app: await _app());

  Future<FirebaseFirestore> _firestore() async =>
      FirebaseFirestore.instanceFor(app: await _app());

  @override
  Future<ParentAccount?> currentAdmin() async {
    final user = (await _auth()).currentUser;
    if (user == null) return null;

    final account = await _accountForUser(user);
    if (account == null) {
      await signOut();
      return null;
    }
    return account;
  }

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    final auth = await _auth();

    final UserCredential credential;
    try {
      credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException {
      // UC-18 deliberately does not distinguish wrong-user from wrong-password.
      throw const AdminAuthException(AdminAuthMessages.invalidCredentials);
    }

    final user = credential.user;
    if (user == null) {
      throw const AdminAuthException(AdminAuthMessages.invalidCredentials);
    }

    final account = await _accountForUser(user);
    if (account == null) {
      // Credentials were valid but this is a parent account, not an admin.
      await signOut();
      throw const AdminAuthException(AdminAuthMessages.notAnAdmin);
    }

    return account;
  }

  @override
  Future<void> signOut() async {
    await (await _auth()).signOut();
  }

  /// Returns the account only when `parents/{uid}.role == 'admin'`.
  Future<ParentAccount?> _accountForUser(User user) async {
    final firestore = await _firestore();
    final snapshot = await firestore.collection('parents').doc(user.uid).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data() ?? const <String, dynamic>{};
    if (!_isAdmin(data)) return null;

    return ParentAccount(
      id: user.uid,
      email: user.email ?? (data['email'] as String? ?? ''),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      role: ParentRole.admin,
    );
  }

  bool _isAdmin(Map<String, dynamic> data) {
    if (data['isAdmin'] == true) return true;
    final role = data['role'];
    return role is String && role.trim().toLowerCase() == _adminRoleValue;
  }
}
