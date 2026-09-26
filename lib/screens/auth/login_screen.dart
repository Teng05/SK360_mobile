import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final email = await MobileApiService.rememberedEmail();
    if (!mounted || email == null) return;

    _emailController.text = email;
    setState(() => _rememberMe = true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppAuthLayout(
      title: 'Welcome back',
      subtitle: 'Your council. Your community.\nOne connected workspace.',
      step: 'YOUTH GOVERNANCE · LIPA CITY',
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInputField(
            label: 'Email address',
            hintText: 'you@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 20),
          AppInputField(
            label: 'Password',
            hintText: 'Enter your password',
            controller: _passwordController,
            isPassword: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) _handleLogin();
            },
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: _isLoading
                        ? null
                        : (value) =>
                              setState(() => _rememberMe = value ?? false),
                  ),
                  const Flexible(child: Text('Remember email')),
                ],
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.resetPassword),
                child: const Text('Forgot password?'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppButton(
            label: _isLoading ? 'Signing in…' : 'Sign in',
            isLoading: _isLoading,
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_rememberMe) {
        await MobileApiService.rememberEmail(email);
      } else {
        await MobileApiService.clearRememberedEmail();
      }

      final response = await MobileApiService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final user = response['user'] as Map<String, dynamic>?;
      final role = user?['role']?.toString();

      Navigator.pushReplacementNamed(context, _homeRouteForRole(role));
    } on MobileApiException catch (exception) {
      if (!mounted) return;
      _showMessage(exception.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Login failed. Please try again.');
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

  String _homeRouteForRole(String? role) {
    return switch (role) {
      'sk_president' => AppRoutes.presidentHome,
      'sk_chairman' => AppRoutes.chairmanHome,
      'sk_secretary' => AppRoutes.secretaryHome,
      _ => AppRoutes.login,
    };
  }
}
