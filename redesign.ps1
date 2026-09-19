$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Read-Source([string]$path) { [IO.File]::ReadAllText((Join-Path $PSScriptRoot $path)) }
function Write-Source([string]$path, [string]$text) { [IO.File]::WriteAllText((Join-Path $PSScriptRoot $path), $text, $utf8) }
function Replace-Build([string]$text, [string]$class, [string]$body) {
  $start = $text.IndexOf('class ' + $class + ' ')
  if ($start -lt 0) { throw "Class missing: $class" }
  $start = $text.IndexOf('Widget build(BuildContext context) {', $start)
  if ($start -lt 0) { throw "Build missing: $class" }
  $open = $text.IndexOf('{', $start)
  $depth = 1; $end = $open + 1
  while ($depth -gt 0) {
    if ($text[$end] -eq '{') { $depth++ }
    if ($text[$end] -eq '}') { $depth-- }
    $end++
  }
  return $text.Substring(0, $open + 1) + "`n" + $body + "`n  }" + $text.Substring($end)
}

$p = 'lib/main.dart'; $s = Read-Source $p
$s = [regex]::Replace($s, 'theme: ThemeData\([\s\S]*?\n      \),', 'theme: AppTheme.light,', 1)
$s = $s.Replace('Duration(seconds: 6)', 'Duration(milliseconds: 650)')
$s = $s.Replace('SizedBox(height: 80)', 'SizedBox(height: 16)').Replace("'Empowering SK Governance'", "'Youth governance. Connected.'")
$s = $s.Replace('value: _progressController.value,', 'value: null,').Replace("'Starting your app...'", "'Opening your workspace…'")
Write-Source $p $s

$p = 'lib/widgets/president_components.dart'; $s = Read-Source $p
$s = Replace-Build $s 'PresidentHeader' @'
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 14),
      child: Row(children: [
        if (leading != PresidentHeaderLeading.none)
          IconButton(
            tooltip: leading == PresidentHeaderLeading.menu ? 'Open menu' : 'Back',
            onPressed: onLeadingTap,
            icon: Icon(leading == PresidentHeaderLeading.menu ? Icons.menu_rounded : Icons.arrow_back_rounded),
          )
        else const SizedBox(width: 12),
        const SizedBox(width: 4),
        Expanded(child: customContent ?? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
          ],
        )),
        const NotificationBell(),
        if (trailing != null) ...trailing!,
      ]),
    );
'@
# Remove the now-unused private center builder.
$s = [regex]::Replace($s, '\n  Widget _buildDefaultCenter\(\) \{[\s\S]*?\n  \}\n', "`n")
$s = Replace-Build $s 'PresidentBottomNavBar' @'
    return Material(
      color: AppColors.surface,
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Row(children: _items.map((item) {
          final selected = item.item == activeItem;
          return Expanded(child: Semantics(
            selected: selected, button: true, label: item.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: selected ? null : () => onItemSelected(item.item),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                    decoration: BoxDecoration(color: selected ? AppColors.softPink : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.icon, size: 23, color: selected ? AppColors.primaryRed : AppColors.lightText)),
                  const SizedBox(height: 4),
                  Text(item.label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primaryRed : AppColors.lightText)),
                ])),
            ),
          ));
        }).toList()),
      )),
    );
'@
$s = Replace-Build $s 'PresidentSideDrawer' @'
    final role = _currentRole();
    final isOfficial = role == 'sk_chairman' || role == 'sk_secretary';
    final menuItems = isOfficial ? _chairmanItems : _presidentItems;
    final roleLabel = switch (role) {
      'sk_chairman' => 'SK Chairman',
      'sk_secretary' => 'SK Secretary',
      _ => 'SK Federation President',
    };
    return Drawer(backgroundColor: AppColors.surface, child: SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const AppHeader(),
        const SizedBox(height: 12),
        AppStatusBadge(label: roleLabel, color: AppColors.primaryRed),
        const SizedBox(height: 24),
        const Text('YOUR WORKSPACE', style: TextStyle(fontSize: 12, letterSpacing: 1, color: AppColors.lightText, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...menuItems.map((item) {
          final selected = _selectedItem(context) == item.label;
          return Padding(padding: const EdgeInsets.only(bottom: 4), child: ListTile(
            selected: selected, selectedColor: AppColors.primaryRed, selectedTileColor: AppColors.softPink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Icon(item.icon, size: 22),
            title: Text(item.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            onTap: () => _handleMenuItemTap(context, item.label),
          ));
        }),
        const Divider(),
        const Text('Serving the youth of Lipa City', style: TextStyle(color: AppColors.lightText, fontSize: 13)),
      ]),
    ));
'@
$s = $s.Replace("AppRoutes.reports => 'View Reports',", "AppRoutes.reports => _currentRole() == 'sk_president' ? 'View Reports' : 'Reports',")
# Don't push the current destination repeatedly.
$s = $s.Replace('void handleRoleNavSelection(BuildContext context, PresidentNavItem item) {', @'
void handleRoleNavSelection(BuildContext context, PresidentNavItem item) {
  final destination = switch (item) {
    PresidentNavItem.home => _homeRouteForCurrentRole(),
    PresidentNavItem.calendar => AppRoutes.presidentCalendar,
    PresidentNavItem.chat => AppRoutes.presidentMessages,
    PresidentNavItem.profile => AppRoutes.profile,
    PresidentNavItem.announcements => AppRoutes.announcements,
    PresidentNavItem.leadership => AppRoutes.leadershipProfiles,
    PresidentNavItem.rankings => AppRoutes.rankings,
  };
  if (ModalRoute.of(context)?.settings.name == destination) return;
'@)
Write-Source $p $s

$p = 'lib/screens/auth/login_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_LoginScreenState' @'
    return AppAuthLayout(
      title: 'Welcome back',
      subtitle: 'Your council. Your community.\nOne connected workspace.',
      step: 'YOUTH GOVERNANCE · LIPA CITY', showBack: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppInputField(label: 'Email address', hintText: 'you@example.com', controller: _emailController,
          keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next, enabled: !_isLoading),
        const SizedBox(height: 20),
        AppInputField(label: 'Password', hintText: 'Enter your password', controller: _passwordController,
          isPassword: true, autofillHints: const [AutofillHints.password], textInputAction: TextInputAction.done,
          onSubmitted: (_) { if (!_isLoading) _handleLogin(); }, enabled: !_isLoading),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(value: _rememberMe, onChanged: _isLoading ? null : (value) => setState(() => _rememberMe = value ?? false)),
            const Text('Remember email'),
          ]),
          TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.resetPassword), child: const Text('Forgot password?')),
        ]),
        const SizedBox(height: 20),
        AppButton(label: _isLoading ? 'Signing in…' : 'Sign in', isLoading: _isLoading, onPressed: _handleLogin),
      ]),
    );
'@
Write-Source $p $s

$p = 'lib/screens/auth/registration_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_RegistrationScreenState' @'
    return AppAuthLayout(title: 'Create your account', subtitle: 'Start with your details and the barangay you serve.', step: 'STEP 1 OF 3 · YOUR DETAILS',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppAdaptiveRow(children: [
          Expanded(child: AppInputField(label: 'First name', hintText: 'First name', controller: _firstNameController, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words)),
          const SizedBox(width: 16),
          Expanded(child: AppInputField(label: 'Last name', hintText: 'Last name', controller: _lastNameController, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words)),
        ]),
        const SizedBox(height: 20),
        AppInputField(label: 'Email address', hintText: 'you@example.com', controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
        const SizedBox(height: 20),
        AppInputField(label: 'Phone number', hintText: '09XX XXX XXXX', controller: _phoneController, keyboardType: TextInputType.phone),
        const SizedBox(height: 20), _buildBarangayDropdown(),
        const SizedBox(height: 28), AppButton(label: 'Continue', onPressed: _continueToPassword),
        const SizedBox(height: 12),
        TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.login), child: const Text('Already have an account? Sign in')),
      ]));
'@
Write-Source $p $s

$p = 'lib/screens/auth/set_password_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_SetPasswordScreenState' @'
    return AppAuthLayout(title: 'Secure your account', subtitle: 'Choose a strong password to protect your workspace.', step: 'STEP 2 OF 3 · ACCOUNT SECURITY',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppInputField(label: 'Password', hintText: 'Create a password', controller: _passwordController, isPassword: true,
          autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.next),
        const SizedBox(height: 8),
        const Text('Use at least 8 characters with uppercase, lowercase, and a number.', style: TextStyle(color: AppColors.lightText, fontSize: 13)),
        const SizedBox(height: 20),
        AppInputField(label: 'Confirm password', hintText: 'Re-enter your password', controller: _confirmPasswordController, isPassword: true),
        const SizedBox(height: 20),
        AppCheckboxAgreement(isChecked: _isAgreed, onChanged: (value) => setState(() => _isAgreed = value),
          text: 'I agree to the Terms of Service and Privacy Policy, and understand that account access depends on my role.'),
        const SizedBox(height: 24),
        AppButton(label: _isLoading ? 'Creating account…' : 'Create account', isLoading: _isLoading, onPressed: _createAccount),
      ]));
'@
Write-Source $p $s

$p = 'lib/screens/auth/verification_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_VerificationScreenState' @'
    return AppAuthLayout(title: 'Check your inbox', subtitle: 'Enter the 6-digit verification code sent to ${widget.email}.', step: 'STEP 3 OF 3 · VERIFICATION',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildOtpRow(), const SizedBox(height: 24),
        AppButton(label: _isLoading ? 'Verifying…' : 'Verify account', isLoading: _isLoading, onPressed: _verifyAccount),
        const SizedBox(height: 16),
        const Text('No code yet? Check your spam folder or request another code.', style: TextStyle(color: AppColors.lightText)),
        TextButton(onPressed: _isLoading ? null : _resendCode, child: const Text('Resend code')),
      ]));
'@
# Flexible OTP cells instead of six fixed 48px boxes.
$s = $s.Replace('return SizedBox(' + "`r`n" + '          width: 48,', 'return Expanded(').Replace('return SizedBox(' + "`n" + '          width: 48,', 'return Expanded(')
$s = $s.Replace("counterText: '',", "counterText: '',`n              contentPadding: const EdgeInsets.symmetric(vertical: 16),`n              semanticCounterText: 'Verification digit',")
Write-Source $p $s

$p = 'lib/screens/auth/reset_password_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_ResetPasswordScreenState' @'
    return AppAuthLayout(title: _codeSent ? 'Set a new password' : 'Forgot your password?',
      subtitle: _codeSent ? 'Enter the code sent to $_target, then choose your new password.' : 'Choose where to receive your reset code.',
      step: _codeSent ? 'STEP 2 OF 2 · RESET PASSWORD' : 'STEP 1 OF 2 · RECOVERY',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!_codeSent) ...[
          _MethodToggle(method: _method, onChanged: (value) => setState(() => _method = value)),
          const SizedBox(height: 24),
          AppInputField(label: _method == 'email' ? 'Email address' : 'Phone number',
            hintText: _method == 'email' ? 'you@example.com' : '+63 9XX XXX XXXX',
            controller: _method == 'email' ? _emailController : _phoneController,
            keyboardType: _method == 'email' ? TextInputType.emailAddress : TextInputType.phone),
          const SizedBox(height: 24),
          AppButton(label: _isLoading ? 'Sending code…' : 'Send reset code', isLoading: _isLoading, onPressed: _sendCode),
        ] else ...[
          AppInputField(label: 'Verification code', hintText: '6-digit code', controller: _codeController,
            keyboardType: TextInputType.number, maxLength: 6, autofillHints: const [AutofillHints.oneTimeCode], textInputAction: TextInputAction.next),
          const SizedBox(height: 20),
          AppInputField(label: 'New password', hintText: 'Create a password', controller: _passwordController, isPassword: true, textInputAction: TextInputAction.next),
          const SizedBox(height: 20),
          AppInputField(label: 'Confirm password', hintText: 'Re-enter your password', controller: _confirmController, isPassword: true),
          const SizedBox(height: 24),
          AppButton(label: _isLoading ? 'Resetting password…' : 'Reset password', isLoading: _isLoading, onPressed: _resetPassword),
          const SizedBox(height: 12),
          const Text('Your code expires in 15 minutes.', style: TextStyle(color: AppColors.lightText, fontSize: 13)),
          TextButton(onPressed: _isLoading ? null : _resetFlow, child: const Text('Use a different method')),
        ],
      ]));
'@
# Keep the network methods; remove superseded presentation methods and helpers.
$start = $s.IndexOf('  Widget _buildRequestView()')
$end = $s.IndexOf('  Future<void> _sendCode()', $start)
$s = $s.Remove($start, $end - $start)
$start = $s.IndexOf('const _titleStyle')
$toggle = $s.IndexOf('class _MethodToggle')
$s = $s.Remove($start, $toggle - $start)
$start = $s.IndexOf('class _LabeledField')
$s = $s.Substring(0, $start)
$s = $s.Replace('const Color(0xFFFCE4E4)', 'AppColors.field')
Write-Source $p $s
