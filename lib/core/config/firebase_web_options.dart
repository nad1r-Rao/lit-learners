import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration supplied at build time.
///
/// `Firebase.initializeApp()` reads `google-services.json` on Android and
/// `GoogleService-Info.plist` on iOS, but the web has no equivalent file — it
/// needs [FirebaseOptions] passed explicitly. This is the seam for that.
///
/// Two ways to connect, in order of preference:
///
/// 1. Run `flutterfire configure`, which writes `lib/firebase_options.dart`
///    covering every platform, then pass
///    `DefaultFirebaseOptions.currentPlatform` in `main.dart`.
/// 2. Or pass the values from **Firebase console → Project settings → Your
///    apps → Web app → SDK setup and configuration** as dart-defines, with no
///    generated file and nothing committed:
///
/// ```sh
/// flutter run -d chrome \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=1:90244160657:web:... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=90244160657 \
///   --dart-define=FIREBASE_PROJECT_ID=little-learner-9d2f1 \
///   --dart-define=FIREBASE_AUTH_DOMAIN=little-learner-9d2f1.firebaseapp.com \
///   --dart-define=FIREBASE_STORAGE_BUCKET=little-learner-9d2f1.firebasestorage.app
/// ```
///
/// Nothing here is a secret: a Firebase web API key identifies the project, it
/// does not authorize anything. Access is controlled by `firestore.rules` and
/// `storage.rules`.
class FirebaseWebOptions {
  const FirebaseWebOptions._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

  /// True when every required value was supplied.
  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  /// Which required values are missing, for a message worth reading.
  static List<String> get missingKeys => [
        if (apiKey.isEmpty) 'FIREBASE_API_KEY',
        if (appId.isEmpty) 'FIREBASE_APP_ID',
        if (messagingSenderId.isEmpty) 'FIREBASE_MESSAGING_SENDER_ID',
        if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      ];

  /// Options built from the dart-defines, or null to let Firebase fall back to
  /// the per-platform config files.
  static FirebaseOptions? resolveOrNull() {
    if (!isConfigured) return null;

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}
