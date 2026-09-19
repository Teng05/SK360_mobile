import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import 'set_password_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  List<Map<String, dynamic>> _barangays = [];
  int? _selectedBarangayId;
  bool _isLoadingBarangays = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  @override
  Widget build(BuildContext context) {
    return AppAuthLayout(
      title: 'Create your account',
      subtitle: 'Start with your details and the barangay you serve.',
      step: 'STEP 1 OF 3 · YOUR DETAILS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppAdaptiveRow(
            children: [
              Expanded(
                child: AppInputField(
                  label: 'First name',
                  hintText: 'First name',
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppInputField(
                  label: 'Last name',
                  hintText: 'Last name',
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppInputField(
            label: 'Email address',
            hintText: 'you@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          AppInputField(
            label: 'Phone number',
            hintText: '09XX XXX XXXX',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _buildBarangayDropdown(),
          const SizedBox(height: 28),
          AppButton(label: 'Continue', onPressed: _continueToPassword),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBarangays() async {
    try {
      final barangays = await MobileApiService.barangays();
      if (!mounted) return;
      setState(() {
        _barangays = barangays;
        _isLoadingBarangays = false;
      });
    } on MobileApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _isLoadingBarangays = false;
      });
      _showMessage(exception.message);
    }
  }

  Widget _buildBarangayDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Barangay',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _selectedBarangayId,
          items: _barangays
              .map(
                (barangay) => DropdownMenuItem<int>(
                  value: barangay['barangay_id'] as int,
                  child: Text(barangay['barangay_name'].toString()),
                ),
              )
              .toList(),
          onChanged: _isLoadingBarangays
              ? null
              : (value) {
                  setState(() {
                    _selectedBarangayId = value;
                  });
                },
          decoration: InputDecoration(
            hintText: _isLoadingBarangays
                ? 'Loading barangays...'
                : 'Select your barangay',
            filled: true,
            fillColor: AppColors.field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpace.controlRadius),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpace.controlRadius),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpace.controlRadius),
              borderSide: const BorderSide(
                color: AppColors.primaryRed,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: const Icon(
              Icons.location_on_outlined,
              color: AppColors.lightText,
            ),
          ),
        ),
      ],
    );
  }

  void _continueToPassword() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        _selectedBarangayId == null) {
      _showMessage('Complete all registration fields.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetPasswordScreen(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phoneNumber: phone,
          barangayId: _selectedBarangayId!,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
