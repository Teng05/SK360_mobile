import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';
import '../../widgets/community_avatar.dart';

class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = MobileApiService.currentUser ?? {};
    final name = [user['first_name'], user['last_name']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' ');
    final photo = user['profile_pic_url']?.toString();
    final role = switch (user['role']) {
      'sk_president' => 'SK Federation President',
      'sk_chairman' => 'SK Chairman',
      'sk_secretary' => 'SK Secretary',
      _ => 'SK official',
    };
    return Scaffold(
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: PresidentNavItem.profile,
        onItemSelected: (item) => _handleNav(context, item),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PresidentHeader(
              leading: PresidentHeaderLeading.none,
              title: 'Your profile',
              subtitle: 'Account and security',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: DecoratedBox(
                decoration: AppDecorations.surface(),
                child: Column(
                  children: [
                    Container(
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.softPink,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppSpace.radius),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -34),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                boxShadow: AppDecorations.softShadow,
                              ),
                              child: CommunityAvatar(
                                name: name,
                                photoUrl: photo,
                                radius: 36,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? 'SK 360 User' : name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                AppStatusBadge(
                                  label: role,
                                  color: AppColors.primaryRed,
                                  icon: Icons.verified_rounded,
                                ),
                              ],
                            ),
                          ),
                          _InfoRow(
                            icon: Icons.mail_outline_rounded,
                            color: AppColors.info,
                            label: 'Email',
                            value: user['email']?.toString() ?? '',
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.location_city_outlined,
                            color: AppColors.primaryRed,
                            label: 'Barangay',
                            value: user['barangay_name']?.toString() ?? '',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: AppSectionHeading(title: 'Account settings'),
            ),
            _ProfileAction(
              icon: Icons.edit_outlined,
              label: 'Edit profile',
              caption: 'Name and profile photo',
              color: AppColors.info,
              onTap: _openEditProfile,
            ),
            _ProfileAction(
              icon: Icons.lock_outline,
              label: 'Change password',
              caption: 'Verified by email code',
              color: AppColors.highlight,
              onTap: _openPasswordPage,
            ),
            const SizedBox(height: 16),
            _ProfileAction(
              icon: Icons.logout,
              label: 'Sign out',
              color: AppColors.primaryRed,
              onTap: () async {
                await MobileApiService.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleNav(BuildContext context, PresidentNavItem item) {
    if (item == PresidentNavItem.profile) return;
    handleRoleNavSelection(context, item);
  }

  Future<void> _openEditProfile() async {
    final user = MobileApiService.currentUser ?? {};
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditProfilePage(
          firstName: user['first_name']?.toString() ?? '',
          lastName: user['last_name']?.toString() ?? '',
          profilePictureUrl: user['profile_pic_url']?.toString(),
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {});
      _showMessage('Profile updated.');
    }
  }

  Future<void> _openPasswordPage() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _ChangePasswordPage()),
    );
    if (changed == true && mounted) {
      _showMessage('Password updated successfully.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditProfilePage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String? profilePictureUrl;

  const _EditProfilePage({
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
  });

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  bool _isSaving = false;
  bool _isPicking = false;
  String? _error;
  XFile? _profilePicture;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'Complete both name fields.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await MobileApiService.updateProfile(
        firstName: first,
        lastName: last,
        profilePicture: _profilePicture == null
            ? null
            : File(_profilePicture!.path),
      );
      if (mounted) Navigator.pop(context, true);
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _choosePicture() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final picture = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picture != null && mounted) {
        setState(() {
          _profilePicture = picture;
          _error = null;
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        final message =
            'Cannot open phone gallery: ${error.message ?? error.code}';
        setState(() => _error = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.darkGray,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.softPink,
                  backgroundImage: _profilePicture != null
                      ? FileImage(File(_profilePicture!.path))
                      : (widget.profilePictureUrl == null
                            ? null
                            : NetworkImage(widget.profilePictureUrl!)),
                  child:
                      _profilePicture == null &&
                          widget.profilePictureUrl == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.primaryRed,
                          size: 48,
                        )
                      : null,
                ),
                TextButton.icon(
                  onPressed: _isSaving || _isPicking ? null : _choosePicture,
                  icon: _isPicking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _isPicking
                        ? 'Opening gallery...'
                        : 'Change profile picture',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Update your information',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your changes will also appear on the web account.',
            style: TextStyle(color: AppColors.lightText),
          ),
          const SizedBox(height: 24),
          _ProfileInput(
            controller: _firstNameController,
            hint: 'First name',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _ProfileInput(
            controller: _lastNameController,
            hint: 'Last name',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.primaryRed)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_otpSent) {
      if (_currentController.text.isEmpty ||
          _newController.text.isEmpty ||
          _confirmController.text.isEmpty) {
        setState(() => _error = 'Complete all password fields.');
        return;
      }
      if (_newController.text != _confirmController.text) {
        setState(() => _error = 'New password and confirmation do not match.');
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        await MobileApiService.requestPasswordChange(
          currentPassword: _currentController.text,
          password: _newController.text,
          passwordConfirmation: _confirmController.text,
        );
        if (mounted) setState(() => _otpSent = true);
      } on MobileApiException catch (exception) {
        if (mounted) setState(() => _error = exception.message);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (_otpController.text.trim().length != 6) {
      setState(() => _error = 'Enter the complete 6-digit OTP.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await MobileApiService.verifyPasswordChange(
        code: _otpController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _currentPasswordHint {
    final updatedAt = MobileApiService.currentUser?['password_updated_at']
        ?.toString();
    final date = updatedAt == null ? null : DateTime.tryParse(updatedAt);
    if (date == null) return 'Current password';
    return 'Current password (Updated ${date.month}/${date.day}/${date.year})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        title: Text(_otpSent ? 'Verify Password Change' : 'Change Password'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.darkGray,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _otpSent ? 'Email verification' : 'Set a new password',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _otpSent
                ? 'Enter the 6-digit code sent to your registered email.'
                : 'Enter your current password, then choose and confirm a new one.',
            style: const TextStyle(color: AppColors.lightText),
          ),
          const SizedBox(height: 24),
          if (!_otpSent) ...[
            _ProfileInput(
              controller: _currentController,
              hint: _currentPasswordHint,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _ProfileInput(
              controller: _newController,
              hint: 'New password',
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _ProfileInput(
              controller: _confirmController,
              hint: 'Re-type new password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isLoading) _submit();
              },
            ),
          ] else
            _ProfileInput(
              controller: _otpController,
              hint: '6-digit verification code',
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.primaryRed)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
          ),
        ],
      ),
    );
  }
}

class _ProfileInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  const _ProfileInput({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AppInputField(
      label: hint,
      hintText: obscureText ? 'Enter password' : hint,
      controller: controller,
      isPassword: obscureText,
      keyboardType: keyboardType ?? TextInputType.text,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppIconTile(icon: icon, color: color, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 1),
            Text(
              value.isEmpty ? 'Not provided' : value,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final Color color;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.color = AppColors.primaryRed,
  });

  @override
  Widget build(BuildContext context) {
    final destructive = icon == Icons.logout;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: AppDecorations.surface(
          color: destructive ? AppColors.softPink : AppColors.surface,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpace.radius),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
            leading: AppIconTile(icon: icon, color: color, size: 19),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: destructive ? AppColors.actionRed : AppColors.darkGray,
              ),
            ),
            subtitle: caption == null ? null : Text(caption!),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: destructive ? AppColors.actionRed : AppColors.lightText,
            ),
          ),
        ),
      ),
    );
  }
}
