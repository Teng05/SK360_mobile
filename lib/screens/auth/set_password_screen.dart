import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import 'verification_screen.dart';

class SetPasswordScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final int barangayId;

  const SetPasswordScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.barangayId,
  });

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isAgreed = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppAuthLayout(
      title: 'Secure your account',
      subtitle: 'Choose a strong password to protect your workspace.',
      step: 'STEP 2 OF 3 · ACCOUNT SECURITY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInputField(
            label: 'Password',
            hintText: 'Create a password',
            controller: _passwordController,
            isPassword: true,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use at least 8 characters with uppercase, lowercase, and a number.',
            style: TextStyle(color: AppColors.lightText, fontSize: 13),
          ),
          const SizedBox(height: 20),
          AppInputField(
            label: 'Confirm password',
            hintText: 'Re-enter your password',
            controller: _confirmPasswordController,
            isPassword: true,
          ),
          const SizedBox(height: 20),
          AppCheckboxAgreement(
            isChecked: _isAgreed,
            onChanged: (value) => setState(() => _isAgreed = value),
            text:
                'I agree to the Terms of Service and Privacy Policy, and understand that account access depends on my role.',
          ),
          const SizedBox(height: 24),
          AppButton(
            label: _isLoading ? 'Creating account…' : 'Create account',
            isLoading: _isLoading,
            onPressed: _createAccount,
          ),
        ],
      ),
    );
  }

  Future<void> _createAccount() async {
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;

    if (!_isAgreed) {
      _showMessage('Please agree to the terms before creating an account.');
      return;
    }

    if (password != confirmation) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await MobileApiService.register(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
        phoneNumber: widget.phoneNumber,
        barangayId: widget.barangayId,
        password: password,
        passwordConfirmation: confirmation,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent to ${widget.email}'),
          backgroundColor: AppColors.primaryRed,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(email: widget.email),
        ),
      );
    } on MobileApiException catch (exception) {
      if (!mounted) return;
      _showMessage(exception.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Registration failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
