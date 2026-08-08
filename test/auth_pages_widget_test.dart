import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';
import 'package:little_learners/views/auth/forgot_password_page.dart';
import 'package:little_learners/views/auth/login_page.dart';
import 'package:little_learners/views/auth/signup_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('LoginPage wooden form remains overflow-free on a compact phone',
      (tester) async {
    final errorCapture = _FlutterErrorCapture.start();
    addTearDown(errorCapture.restore);

    await _pumpAuthPage(tester, const LoginPage());
    errorCapture.restore();

    expect(find.text('PARENT'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(errorCapture.errors, isEmpty);
  });

  testWidgets('SignupPage keeps its minimal wooden form responsive',
      (tester) async {
    final errorCapture = _FlutterErrorCapture.start();
    addTearDown(errorCapture.restore);

    await _pumpAuthPage(tester, const SignupPage());
    await tester.enterText(
      find.byType(TextField).last,
      'StrongPass1!',
    );
    await tester.pump();
    errorCapture.restore();

    expect(find.text('CREATE'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(
      find.text('8+ characters with uppercase, number and symbol'),
      findsOneWidget,
    );
    expect(errorCapture.errors, isEmpty);
  });

  testWidgets('LoginPage offers Google alongside the password form',
      (tester) async {
    await _pumpAuthPage(tester, const LoginPage());

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('ForgotPasswordPage walks email, code and new password',
      (tester) async {
    final repository = InMemoryAuthRepository();
    await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
    await _pumpAuthPage(
      tester,
      const ForgotPasswordPage(),
      repository: repository,
      // Taller than the other auth pages: the last step shows two password
      // fields plus the rules line, and every control has to be tappable.
      size: const Size(390, 844),
    );

    expect(find.text('RESET'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'parent@example.com');
    await _tap(tester, 'Send code');

    expect(find.text('Verify code'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      repository.lastOtpFor('parent@example.com')!,
    );
    await _tap(tester, 'Verify code');

    expect(find.text('Save new password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Brand1New!');
    await tester.enterText(find.byType(TextField).last, 'Brand1New!');
    await _tap(tester, 'Save new password');

    expect(find.text('Back to sign in'), findsOneWidget);

    // The point of the whole flow: the account really does take the new
    // password now.
    final signedIn = await repository.signIn(
      email: 'parent@example.com',
      password: 'Brand1New!',
    );

    expect(signedIn.email, 'parent@example.com');
  });
}

/// Taps the button carrying [label] and lets the resulting rebuild finish.
Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pumpAuthPage(
  WidgetTester tester,
  Widget page, {
  InMemoryAuthRepository? repository,
  Size size = const Size(320, 568),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthViewModel(repository ?? InMemoryAuthRepository()),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FlutterErrorCapture {
  _FlutterErrorCapture._(this._originalOnError);

  final void Function(FlutterErrorDetails)? _originalOnError;
  final errors = <FlutterErrorDetails>[];
  bool _restored = false;

  static _FlutterErrorCapture start() {
    final capture = _FlutterErrorCapture._(FlutterError.onError);
    FlutterError.onError = capture.errors.add;
    return capture;
  }

  void restore() {
    if (_restored) return;
    FlutterError.onError = _originalOnError;
    _restored = true;
  }
}
