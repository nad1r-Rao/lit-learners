import 'package:cloud_functions/cloud_functions.dart';

import '../../core/config/app_config.dart';
import '../../repositories/auth_repository.dart';

/// The three server calls behind the OTP reset. Firebase Auth has no
/// client-side way to set a password for an account nobody is signed in to, so
/// the actual write happens in a Cloud Function using the Admin SDK.
abstract class PasswordResetRemoteDataSource {
  Future<void> requestOtp(String email);

  Future<String> verifyOtp({required String email, required String otp});

  Future<void> confirmReset({
    required String email,
    required String resetToken,
    required String newPassword,
  });
}

class FunctionsPasswordResetService implements PasswordResetRemoteDataSource {
  FunctionsPasswordResetService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<void> requestOtp(String email) async {
    await _call('requestPasswordResetOtp', {
      'email': email.trim().toLowerCase(),
    });
  }

  @override
  Future<String> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final data = await _call('verifyPasswordResetOtp', {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
    });

    final token = data?['resetToken'];
    if (token is! String || token.isEmpty) {
      throw const AuthException(
        'The server did not return a reset token. Please try again.',
      );
    }
    return token;
  }

  @override
  Future<void> confirmReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _call('resetPasswordWithOtp', {
      'email': email.trim().toLowerCase(),
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>?> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call<dynamic>(
            payload,
          );
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on FirebaseFunctionsException catch (error) {
      throw AuthException(passwordResetMessageFor(error));
    }
  }
}

String passwordResetMessageFor(FirebaseFunctionsException error) {
  final message = error.message ?? '';
  switch (error.code) {
    case 'not-found':
      return 'No account found for this email.';
    case 'invalid-argument':
      return message.isEmpty ? 'That code is not correct.' : message;
    case 'deadline-exceeded':
    case 'failed-precondition':
      return message.isEmpty
          ? 'This code has expired. Request a new one.'
          : message;
    case 'permission-denied':
      return message.isEmpty
          ? 'Too many attempts. Request a new code.'
          : message;
    case 'resource-exhausted':
      return 'Too many requests. Wait a minute and try again.';
    case 'unauthenticated':
      return 'Verify the code again before continuing.';
    case 'internal':
    case 'unavailable':
    case 'not-implemented':
      return _functionsSetupMessage;
    default:
      return message.isEmpty
          ? 'Password reset failed. Please try again.'
          : message;
  }
}

const _functionsSetupMessage =
    'The password reset service is unreachable. Deploy the Cloud Functions in '
    '`functions/` with `firebase deploy --only functions`, and check that '
    'FUNCTIONS_REGION matches the deployed region.';
