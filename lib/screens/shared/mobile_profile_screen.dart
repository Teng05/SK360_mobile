import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final user = MobileApiService.currentUser ?? {};
    final name = [
      user['first_name']?.toString(),
      user['last_name']?.toString(),
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    final role = user['role']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
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
              title: 'Profile',
              subtitle: 'Account details',
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderPink),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.softPink,
                      child: Icon(
                        Icons.person,
                        color: AppColors.primaryRed,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.isEmpty ? 'SK 360 User' : name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email']?.toString() ?? '',
                      style: const TextStyle(color: AppColors.lightText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['barangay_name']?.toString() ?? '',
                      style: const TextStyle(color: AppColors.lightText),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProfileAction(
              icon: Icons.edit_outlined,
              label: 'Edit Profile',
              onTap: _showEditProfileDialog,
            ),
            _ProfileAction(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: _showPasswordDialog,
            ),
            if (role != 'youth')
              _ProfileAction(
                icon: Icons.receipt_long,
                label: 'Reports',
                onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
              ),
            _ProfileAction(
              icon: Icons.emoji_events_outlined,
              label: 'Rankings',
              onTap: () => Navigator.pushNamed(context, AppRoutes.rankings),
            ),
            _ProfileAction(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () async {
                if (_isSaving) return;
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

  Future<void> _showEditProfileDialog() async {
    final user = MobileApiService.currentUser ?? {};
    final firstName = TextEditingController(text: user['first_name']?.toString() ?? '');
    final lastName = TextEditingController(text: user['last_name']?.toString() ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstName,
              decoration: const InputDecoration(labelText: 'First name'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: lastName,
              decoration: const InputDecoration(labelText: 'Last name'),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final first = firstName.text.trim();
              final last = lastName.text.trim();
              if (first.isEmpty || last.isEmpty) return;

              Navigator.pop(dialogContext);
              await _saveProfile(first, last);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    firstName.dispose();
    lastName.dispose();
  }

  Future<void> _showPasswordDialog() async {
    final current = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (current.text.isEmpty ||
                  password.text.isEmpty ||
                  confirm.text.isEmpty) {
                return;
              }

              Navigator.pop(dialogContext);
              await _savePassword(current.text, password.text, confirm.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    current.dispose();
    password.dispose();
    confirm.dispose();
  }

  Future<void> _saveProfile(String firstName, String lastName) async {
    setState(() => _isSaving = true);
    try {
      await MobileApiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
      );
      if (mounted) {
        setState(() {});
        _showMessage('Profile updated.');
      }
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePassword(
    String currentPassword,
    String password,
    String confirmation,
  ) async {
    setState(() => _isSaving = true);
    try {
      await MobileApiService.updatePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: confirmation,
      );
      if (mounted) _showMessage('Password updated.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ListTile(
        onTap: onTap,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderPink),
        ),
        leading: Icon(icon, color: AppColors.primaryRed),
        title: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
