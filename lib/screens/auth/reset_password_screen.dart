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
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _method = 'email';
  String _target = '';
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
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
          : 'Choose where to receive your reset code.',
      step: _codeSent
          ? 'STEP 2 OF 2 · RESET PASSWORD'
          : 'STEP 1 OF 2 · RECOVERY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_codeSent) ...[
            _MethodToggle(
              method: _method,
              onChanged: (value) => setState(() => _method = value),
            ),
            const SizedBox(height: 24),
            AppInputField(
              label: _method == 'email' ? 'Email address' : 'Phone number',
              hintText: _method == 'email'
                  ? 'you@example.com'
                  : '+63 9XX XXX XXXX',
              controller: _method == 'email'
                  ? _emailController
                  : _phoneController,
              keyboardType: _method == 'email'
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
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
              child: const Text('Use a different method'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final target = _method == 'email' ? email : phone;
    if (target.isEmpty) {
      _showMessage(
        _method == 'email' ? 'Enter your email.' : 'Enter your phone number.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await MobileApiService.requestPasswordReset(
        method: _method,
        email: _method == 'email' ? email : null,
        phone: _method == 'phone' ? phone : null,
      );
      if (!mounted) return;
      setState(() {
        _target = response['target']?.toString() ?? target;
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
        method: _method,
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

class _MethodToggle extends StatelessWidget {
  final String method;
  final ValueChanged<String> onChanged;

  const _MethodToggle({required this.method, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Email',
            active: method == 'email',
            onTap: () => onChanged('email'),
          ),
          _ToggleButton(
            label: 'Phone',
            active: method == 'phone',
            onTap: () => onChanged('phone'),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: active ? AppColors.primaryRed : Colors.transparent,
          foregroundColor: active ? Colors.white : AppColors.primaryRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
