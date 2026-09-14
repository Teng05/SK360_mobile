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
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(110),
        child: SafeArea(
          child: AppHeader(
            appName: 'SK 360°',
            subtitle: 'SK Governance Platform',
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to access your SK 360° dashboard',
                style: TextStyle(fontSize: 14, color: AppColors.lightText),
              ),
              const SizedBox(height: 32),
              AppInputField(
                label: 'Email Address',
                hintText: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              AppInputField(
                label: 'Password',
                hintText: 'Enter your password',
                controller: _passwordController,
                isPassword: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.primaryRed,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text(
                    'Remember me',
                    style: TextStyle(fontSize: 14, color: AppColors.darkGray),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.resetPassword);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppButton(
                label: _isLoading ? 'Signing In...' : 'Sign In',
                onPressed: _isLoading ? () {} : _handleLogin,
              ),
            ],
          ),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
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
