class AppConfig {
  const AppConfig._();

  static const useFirebase = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: true,
  );

  /// OAuth *Web* client id from the Firebase console. Android reads this from
  /// the generated `default_web_client_id` resource when it is left blank, so
  /// only set it when the generated value is wrong or missing.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// OAuth *iOS* client id. Blank on Android; iOS reads it from
  /// `GoogleService-Info.plist` when left blank.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Region the password-reset Cloud Functions are deployed to. Must match the
  /// region in `functions/index.js`.
  static const functionsRegion = String.fromEnvironment(
    'FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );
}
