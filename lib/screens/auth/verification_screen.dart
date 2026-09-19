import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import 'login_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String email;

  const VerificationScreen({super.key, required this.email});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppAuthLayout(
      title: 'Check your inbox',
      subtitle: 'Enter the 6-digit verification code sent to ${widget.email}.',
      step: 'STEP 3 OF 3 · VERIFICATION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOtpRow(),
          const SizedBox(height: 24),
          AppButton(
            label: _isLoading ? 'Verifying…' : 'Verify account',
            isLoading: _isLoading,
            onPressed: _verifyAccount,
          ),
          const SizedBox(height: 16),
          const Text(
            'No code yet? Check your spam folder or request another code.',
            style: TextStyle(color: AppColors.lightText),
          ),
          TextButton(
            onPressed: _isLoading ? null : _resendCode,
            child: const Text('Resend code'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return Expanded(
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            cursorColor: AppColors.primaryRed,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              semanticCounterText: 'Verification digit',
              filled: true,
              fillColor: AppColors.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primaryRed,
                  width: 2,
                ),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              if (value.isNotEmpty && index < _focusNodes.length - 1) {
                _focusNodes[index + 1].requestFocus();
              }
              if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  Future<void> _verifyAccount() async {
    final code = _controllers.map((controller) => controller.text).join();

    if (code.length != 6) {
      _showMessage('Enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await MobileApiService.verifyRegistration(
        email: widget.email,
        code: code,
      );

      if (!mounted) return;

      _showMessage('Account verified. You can now sign in.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on MobileApiException catch (exception) {
      if (!mounted) return;
      _showMessage(exception.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Verification failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    try {
      await MobileApiService.resendVerificationCode(email: widget.email);
      if (!mounted) return;
      _showMessage('Verification code resent.');
    } on MobileApiException catch (exception) {
      if (!mounted) return;
      _showMessage(exception.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
