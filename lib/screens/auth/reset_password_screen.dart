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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: _codeSent ? _buildVerifyView() : _buildRequestView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestView() {
    return Column(
      children: [
        _LogoCircle(
          backgroundColor: Colors.white,
          child: const Text(
            'SK',
            style: TextStyle(
              color: AppColors.primaryRed,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Text(
          'Reset Your Password',
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose your preferred reset method',
          textAlign: TextAlign.center,
          style: _subTextStyle,
        ),
        const SizedBox(height: 25),
        _Card(
          child: Column(
            children: [
              _MethodToggle(
                method: _method,
                onChanged: (value) => setState(() => _method = value),
              ),
              const SizedBox(height: 25),
              if (_method == 'email')
                _LabeledField(
                  label: 'Email Address',
                  iconText: '@',
                  controller: _emailController,
                  hintText: 'sk360@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                )
              else
                _LabeledField(
                  label: 'Phone Number',
                  iconText: 'P',
                  controller: _phoneController,
                  hintText: '+639123456789',
                  keyboardType: TextInputType.phone,
                ),
              const SizedBox(height: 20),
              _PrimaryButton(
                label: _isLoading ? 'Sending...' : 'Send Reset Code',
                onPressed: _isLoading ? null : _sendCode,
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyView() {
    final isPhone = _method == 'phone';

    return Column(
      children: [
        _LogoCircle(
          backgroundColor: const Color(0xFFFFCA28),
          child: Text(
            isPhone ? '#' : '@',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Text(
          'Reset Code Sent!',
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 8),
        Text(
          isPhone
              ? 'Check your phone for password reset instructions'
              : 'Check your email for password reset instructions',
          textAlign: TextAlign.center,
          style: _subTextStyle,
        ),
        const SizedBox(height: 25),
        _Card(
          child: Column(
            children: [
              _InfoBadge(label: isPhone ? 'Phone' : 'Email', value: _target),
              const SizedBox(height: 16),
              _LabeledField(
                label: isPhone ? 'SMS Code' : 'Email Code',
                iconText: '#',
                controller: _codeController,
                hintText: '6-digit code',
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'New Password',
                iconText: '*',
                controller: _passwordController,
                hintText: 'New password',
                obscureText: true,
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Confirm Password',
                iconText: '*',
                controller: _confirmController,
                hintText: 'Confirm password',
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                label: _isLoading ? 'Resetting...' : 'Reset Password',
                onPressed: _isLoading ? null : _resetPassword,
              ),
              const SizedBox(height: 12),
              const Text(
                'Code expires in 15 minutes',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _resetFlow,
                child: const Text(
                  'Try Different Method',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final target = _method == 'email' ? email : phone;
    if (target.isEmpty) {
      _showMessage(_method == 'email' ? 'Enter your email.' : 'Enter your phone number.');
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
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (_) => false,
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }
}

const _titleStyle = TextStyle(
  color: AppColors.primaryRed,
  fontSize: 28,
  fontWeight: FontWeight.w800,
);

const _subTextStyle = TextStyle(
  color: Color(0xFF6B7280),
  fontSize: 14,
);

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LogoCircle extends StatelessWidget {
  final Color backgroundColor;
  final Widget child;

  const _LogoCircle({required this.backgroundColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
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
        color: const Color(0xFFFCE4E4),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String iconText;
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLength;

  const _LabeledField({
    required this.label,
    required this.iconText,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFCE4E4),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                iconText,
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.darkGray,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          decoration: InputDecoration(
            counterText: '',
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF1F3F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.primaryRed.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFAD4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9D9AB)),
      ),
      child: Text(
        '$label  $value',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF8F763F),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
