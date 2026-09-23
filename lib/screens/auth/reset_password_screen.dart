import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _target = '';
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppAuthLayout(
      title: _codeSent ? 'Set a new password' : 'Forgot your password?',
      subtitle: _codeSent
          ? 'Enter the code sent to $_target, then choose your new password.'
          : 'Enter your registered email to receive a reset code.',
      step: _codeSent
          ? 'STEP 2 OF 2 · RESET PASSWORD'
          : 'STEP 1 OF 2 · RECOVERY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_codeSent) ...[
            AppInputField(
              label: 'Email address',
              hintText: 'you@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: _isLoading ? 'Sending code…' : 'Send reset code',
              isLoading: _isLoading,
              onPressed: _sendCode,
            ),
          ] else ...[
            AppInputField(
              label: 'Verification code',
              hintText: '6-digit code',
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            AppInputField(
              label: 'New password',
              hintText: 'Create a password',
              controller: _passwordController,
              isPassword: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            AppInputField(
              label: 'Confirm password',
              hintText: 'Re-enter your password',
              controller: _confirmController,
              isPassword: true,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: _isLoading ? 'Resetting password…' : 'Reset password',
              isLoading: _isLoading,
              onPressed: _resetPassword,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your code expires in 15 minutes.',
              style: TextStyle(color: AppColors.lightText, fontSize: 13),
            ),
            TextButton(
              onPressed: _isLoading ? null : _resetFlow,
              child: const Text('Use a different email'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await MobileApiService.requestPasswordReset(
        email: email,
      );
      if (!mounted) return;
      setState(() {
        _target = response['target']?.toString() ?? email;
        _codeSent = true;
      });
      _showMessage(response['message']?.toString() ?? 'Reset code sent.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmation = _confirmController.text;
    if (code.length != 6 || password.isEmpty || confirmation.isEmpty) {
      _showMessage('Enter the code and new password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await MobileApiService.verifyPasswordReset(
        target: _target,
        code: code,
        password: password,
        passwordConfirmation: confirmation,
      );
      if (!mounted) return;
      _showMessage(response['message']?.toString() ?? 'Password reset.');
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetFlow() {
    setState(() {
      _codeSent = false;
      _target = '';
      _codeController.clear();
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
