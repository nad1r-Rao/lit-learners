import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// The secondary [FirebaseApp] the admin portal runs on.
///
/// Admin sign-in deliberately does not touch the default app, so that an admin
/// session cannot replace `FirebaseAuth.instance.currentUser` and leak admin
/// identity into the parent/child flow (UC-18).
///
/// **The consequence is easy to miss, and cost a release once:** every admin
/// Firestore *and Storage* call must go through this app as well. A query
/// issued on the default instance runs as the signed-in parent — or as nobody
/// at all — so `isAdmin()` in `firestore.rules` evaluates false and the read
/// fails with `PERMISSION_DENIED`, even though the admin signed in perfectly
/// and the rules are correct and deployed.
///
/// That is why the admin repositories take a **required** `firestore` argument
/// rather than defaulting to `FirebaseFirestore.instance`: the wrong instance
/// is not a mistake the type system should allow.
class AdminFirebaseApp {
  const AdminFirebaseApp._();

  /// Name of the secondary app. Shared by the auth repository and by every
  /// admin data repository, so there is one source of truth.
  static const name = 'littleLearnersAdmin';

  /// Creates the admin app if it does not exist, reusing it otherwise.
  ///
  /// Safe to call repeatedly, including across hot restarts, where the app
  /// survives but Dart state does not.
  ///
  /// Requires the default app to be running, since it borrows its options.
  static Future<FirebaseApp> ensureInitialized() async {
    final existing = appOrNull;
    if (existing != null) return existing;

    return Firebase.initializeApp(
      name: name,
      options: Firebase.app().options,
    );
  }

  /// The admin app, or null when it has not been created yet.
  static FirebaseApp? get appOrNull {
    try {
      return Firebase.app(name);
    } on FirebaseException {
      return null;
    }
  }

  /// Firestore on the admin app.
  ///
  /// Throws when the admin app was never initialized, rather than quietly
  /// handing back the default instance — silently falling back is exactly the
  /// bug this class exists to prevent.
  static FirebaseFirestore get firestore {
    return FirebaseFirestore.instanceFor(app: _requireApp());
  }

  /// Storage on the admin app. Media upload writes here, and `storage.rules`
  /// checks the same admin identity Firestore does.
  static FirebaseStorage get storage {
    return FirebaseStorage.instanceFor(app: _requireApp());
  }

  static FirebaseApp _requireApp() {
    final app = appOrNull;
    if (app == null) {
      throw StateError(
        'The admin Firebase app "$name" has not been initialized. '
        'main.dart must await AdminFirebaseApp.ensureInitialized() once '
        'Firebase is up, before the admin repositories are built.',
      );
    }
    return app;
  }
}
