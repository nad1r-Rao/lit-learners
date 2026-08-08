import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'widgets/auth_page_shell.dart';

/// Three steps on one screen: ask for a code, type the code, choose the new
/// password. Keeping them in one route means the short-lived reset token never
/// has to travel through route arguments.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // A reset abandoned earlier should not drop the parent back into a
    // half-finished flow.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthViewModel>().resetPasswordFlow();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return AuthPageShell(
      titleLeading: 'RESET',
      titleTrailing: 'PASSWORD',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResetStepDots(step: auth.passwordResetStep),
          const SizedBox(height: 16),
          switch (auth.passwordResetStep) {
            PasswordResetStep.requestCode => _buildRequestStep(context, auth),
            PasswordResetStep.verifyCode => _buildVerifyStep(context, auth),
            PasswordResetStep.choosePassword =>
              _buildPasswordStep(context, auth),
            PasswordResetStep.done => _buildDoneStep(context),
          },
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 12),
            AuthMessageBanner(message: auth.errorMessage!),
          ],
          if (auth.infoMessage != null && auth.errorMessage == null) ...[
            const SizedBox(height: 12),
            AuthMessageBanner(message: auth.infoMessage!, isError: false),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestStep(BuildContext context, AuthViewModel auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepCaption(
          'Type the email on your account. We will send a '
          '6-digit code to it.',
        ),
        const SizedBox(height: 14),
        AuthWoodenTextField(
          controller: _emailController,
          label: 'Email address',
          hint: 'parent@example.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onSubmitted: (_) => _requestCode(context),
        ),
        const SizedBox(height: 16),
        AuthActionButton(
          icon: Icons.mark_email_read_rounded,
          label: auth.isLoading ? 'Sending...' : 'Send code',
          onPressed: auth.isLoading ? null : () => _requestCode(context),
        ),
      ],
    );
  }

  Widget _buildVerifyStep(BuildContext context, AuthViewModel auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepCaption(
          'Enter the $passwordResetOtpLength-digit code sent to '
          '${auth.passwordResetEmail ?? 'your email'}.',
        ),
        const SizedBox(height: 14),
        AuthWoodenTextField(
          controller: _otpController,
          label: 'Verification code',
          hint: '123456',
          prefixIcon: Icons.pin_rounded,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: passwordResetOtpLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _verifyCode(context),
        ),
        const SizedBox(height: 8),
        AuthActionButton(
          icon: Icons.verified_rounded,
          label: auth.isLoading ? 'Checking...' : 'Verify code',
          onPressed: auth.isLoading ? null : () => _verifyCode(context),
        ),
        // Two buttons side by side overflow a narrow phone once the labels
        // grow, so they share the width rather than taking their natural size.
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () {
                        _otpController.clear();
                        context.read<AuthViewModel>().editPasswordResetEmail();
                      },
                child: const Text(
                  'Change email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () {
                        _otpController.clear();
                        context.read<AuthViewModel>().resendPasswordResetOtp();
                      },
                child: const Text(
                  'Resend code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordStep(BuildContext context, AuthViewModel auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepCaption('Choose the password you will use from now on.'),
        const SizedBox(height: 14),
        AuthWoodenTextField(
          controller: _passwordController,
          label: 'New password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AuthWoodenTextField(
          controller: _confirmPasswordController,
          label: 'Repeat new password',
          prefixIcon: Icons.lock_reset_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _confirmReset(context),
        ),
        const SizedBox(height: 8),
        const Text(
          '8+ characters with uppercase, number and symbol',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF6F3D20),
            fontFamily: 'Fredoka',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        AuthActionButton(
          icon: Icons.save_rounded,
          label: auth.isLoading ? 'Saving...' : 'Save new password',
          onPressed: auth.isLoading ? null : () => _confirmReset(context),
        ),
      ],
    );
  }

  Widget _buildDoneStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepCaption(
          'Your new password is saved. Sign in with it to continue.',
        ),
        const SizedBox(height: 16),
        AuthActionButton(
          icon: Icons.login_rounded,
          label: 'Back to sign in',
          onPressed: () => _openLogin(context),
        ),
      ],
    );
  }

  void _openLogin(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RouteNames.login);
  }

  Future<void> _requestCode(BuildContext context) {
    return context.read<AuthViewModel>().requestPasswordResetOtp(
          _emailController.text,
        );
  }

  Future<void> _verifyCode(BuildContext context) {
    return context.read<AuthViewModel>().verifyPasswordResetOtp(
          _otpController.text,
        );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final success = await context.read<AuthViewModel>().confirmPasswordReset(
          newPassword: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        );
    if (!success) return;

    _passwordController.clear();
    _confirmPasswordController.clear();
    _otpController.clear();
  }
}

class _StepCaption extends StatelessWidget {
  const _StepCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF6F3D20),
        fontFamily: 'Fredoka',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ResetStepDots extends StatelessWidget {
  const _ResetStepDots({required this.step});

  final PasswordResetStep step;

  @override
  Widget build(BuildContext context) {
    final index = PasswordResetStep.values.indexOf(step);

    return Semantics(
      label: 'Step ${index + 1} of ${PasswordResetStep.values.length}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < PasswordResetStep.values.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == index ? 26 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: i <= index
                      ? const Color(0xFFFFC94A)
                      : const Color(0x806F3D20),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
