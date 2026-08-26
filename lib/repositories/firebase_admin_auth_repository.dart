import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/admin_user.dart';
import '../services/firebase/admin_user_firestore_service.dart';
import 'admin_auth_repository.dart';

/// Firebase-backed admin authentication (UC-18).
///
/// Runs against a secondary [FirebaseApp] so the admin's Firebase Auth session
/// is genuinely independent of the parent session on the default app. Without
/// this, signing in as an admin would replace
/// `FirebaseAuth.instance.currentUser` and leak admin identity into the
/// parent/child flow.
///
/// Admin identity comes from `adminUsers/{uid}` — see
/// [AdminUserFirestoreService] for the schema and
/// `docs/FIREBASE_ADMIN_SETUP.md` for the console steps.
class FirebaseAdminAuthRepository implements AdminAuthRepository {
  FirebaseAdminAuthRepository({
    String adminAppName = 'littleLearnersAdmin',
    bool allowLegacyParentRole = true,
  })  : _adminAppName = adminAppName,
        _allowLegacyParentRole = allowLegacyParentRole;

  final String _adminAppName;
  final bool _allowLegacyParentRole;
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

  Future<FirebaseAuth> _auth() async =>
      FirebaseAuth.instanceFor(app: await _app());

  Future<AdminUserRemoteDataSource> _directory() async {
    return AdminUserFirestoreService(
      firestore: FirebaseFirestore.instanceFor(app: await _app()),
      allowLegacyParentRole: _allowLegacyParentRole,
    );
  }

  @override
  Future<AdminUser?> currentAdmin() async {
    final user = (await _auth()).currentUser;
    if (user == null) return null;

    final admin = await _adminFor(user);
    if (admin == null || !admin.canSignIn) {
      await signOut();
      return null;
    }
    return admin;
  }

  @override
  Future<AdminUser> signIn({
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

    final admin = await _adminFor(user);
    if (admin == null) {
      // Credentials were valid but there is no admin record for this account.
      await signOut();
      throw const AdminAuthException(AdminAuthMessages.notAnAdmin);
    }

    if (!admin.canSignIn) {
      await signOut();
      throw const AdminAuthException(AdminAuthMessages.suspended);
    }

    return admin;
  }

  @override
  Future<void> signOut() async {
    await (await _auth()).signOut();
  }

  Future<AdminUser?> _adminFor(User user) async {
    final directory = await _directory();
    return directory.findAdmin(
      uid: user.uid,
      email: user.email ?? '',
    );
  }
}
