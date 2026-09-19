$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Read-Source([string]$path) { [IO.File]::ReadAllText((Join-Path $PSScriptRoot $path)) }
function Write-Source([string]$path, [string]$text) { [IO.File]::WriteAllText((Join-Path $PSScriptRoot $path), $text, $utf8) }
function Replace-Build([string]$text, [string]$class, [string]$body) {
  $start = $text.IndexOf('class ' + $class + ' ')
  if ($start -lt 0) { throw "Class missing: $class" }
  $start = $text.IndexOf('Widget build(BuildContext context) {', $start)
  $open = $text.IndexOf('{', $start); $depth = 1; $end = $open + 1
  while ($depth -gt 0) { if ($text[$end] -eq '{') { $depth++ }; if ($text[$end] -eq '}') { $depth-- }; $end++ }
  return $text.Substring(0, $open + 1) + "`n" + $body + "`n  }" + $text.Substring($end)
}

$p = 'lib/screens/shared/chat_screen.dart'; $s = Read-Source $p
$s = $s.Replace("title: isThreadOpen ? activeName : 'Chat'", "title: isThreadOpen ? activeName : 'Messages'")
$s = $s.Replace("subtitle: isThreadOpen ? 'Conversation' : 'Messages'", "subtitle: isThreadOpen ? 'Conversation' : 'Keep your council connected'")
$s = $s.Replace('color: Colors.white,' + "`r`n" + '                        ),', 'color: AppColors.darkGray,' + "`r`n" + '                        ),')
$s = $s.Replace('if (_isLoading) const LinearProgressIndicator(minHeight: 3)', 'if (_isLoading || _isLoadingUsers) const LinearProgressIndicator(minHeight: 3)')
$s = Replace-Build $s '_RoomRail' @'
    final searching = searchController.text.trim().isNotEmpty;
    return ListView(padding: const EdgeInsets.all(20), children: [
      TextField(controller: searchController, onChanged: onSearch,
        decoration: InputDecoration(hintText: 'Search people', prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: searching ? IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close),
            onPressed: () { searchController.clear(); onSearch(''); }) : null)),
      const SizedBox(height: 24),
      AppSectionHeading(title: searching ? 'People' : 'Conversations'),
      const SizedBox(height: 12),
      if (searching && users.isEmpty)
        const AppEmptyState(icon: Icons.person_search_outlined, title: 'No matching people', message: 'Try another name.'),
      if (!searching && rooms.isEmpty)
        const AppEmptyState(icon: Icons.chat_bubble_outline, title: 'Start a conversation',
          message: 'Search for an SK official above, or use the group button to bring your council together.'),
      if (searching) ...users.map((user) => _UserTile(user: user, onTap: () => onUserTap(user)))
      else ...rooms.map((room) => _RoomTile(name: room.displayNameFor(currentUserName),
        profilePictureUrl: _roomPhoto(room), active: room.id == activeRoom?.id, onTap: () => onRoomTap(room))),
    ]);
'@
$s = $s.Replace('dense: true,', 'dense: false,').Replace('radius: 16,', 'radius: 24,')
$s = $s.Replace('backgroundColor: AppColors.success,', 'backgroundColor: AppColors.primaryRed,')
$s = $s.Replace('constraints: const BoxConstraints(maxWidth: 250)', 'constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78)')
$s = $s.Replace('color: own ? AppColors.primaryRed : Colors.white', 'color: own ? AppColors.softPink : Colors.white')
$s = $s.Replace('color: own ? Colors.white70 : AppColors.lightText', 'color: AppColors.lightText').Replace('color: own ? Colors.white : AppColors.darkGray', 'color: AppColors.darkGray')
$s = $s.Replace('onPressed: enabled ? onToggleEmojiPicker : null,', "tooltip: 'Choose emoji',`n                onPressed: enabled ? onToggleEmojiPicker : null,")
$s = $s.Replace('onPressed: enabled ? onSend : null,', "tooltip: 'Send message',`n                onPressed: enabled ? onSend : null,")
$s = $s.Replace('                  enabled: enabled,', "                  enabled: enabled,`n                  minLines: 1, maxLines: 4,")
$s = $s.Replace('                        padding: const EdgeInsets.all(4)', '                        padding: const EdgeInsets.all(10)')
Write-Source $p $s

$p = 'lib/screens/shared/mobile_profile_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_MobileProfileScreenState' @'
    final user = MobileApiService.currentUser ?? {};
    final name = [user['first_name'], user['last_name']].where((part) => part != null && part.toString().trim().isNotEmpty).join(' ');
    final photo = user['profile_pic_url']?.toString();
    final role = switch (user['role']) {
      'sk_president' => 'SK Federation President', 'sk_chairman' => 'SK Chairman',
      'sk_secretary' => 'SK Secretary', _ => 'SK official',
    };
    return Scaffold(bottomNavigationBar: PresidentBottomNavBar(activeItem: PresidentNavItem.profile,
      onItemSelected: (item) => _handleNav(context, item)),
      body: SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        const PresidentHeader(leading: PresidentHeaderLeading.none, title: 'Your profile', subtitle: 'Account and security'),
        Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 36, backgroundColor: AppColors.softPink,
            backgroundImage: photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
            child: photo?.isNotEmpty == true ? null : const Icon(Icons.person_outline, color: AppColors.primaryRed, size: 34)),
          const SizedBox(height: 16), Text(name.isEmpty ? 'SK 360 User' : name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8), AppStatusBadge(label: role, color: AppColors.primaryRed),
          const SizedBox(height: 20), Text(user['email']?.toString() ?? '', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4), Text(user['barangay_name']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall),
        ])),
        const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 12), child: AppSectionHeading(title: 'Account settings')),
        _ProfileAction(icon: Icons.edit_outlined, label: 'Edit profile', onTap: _openEditProfile),
        _ProfileAction(icon: Icons.lock_outline, label: 'Change password', onTap: _openPasswordPage),
        const SizedBox(height: 20),
        _ProfileAction(icon: Icons.logout, label: 'Sign out', onTap: () async {
          await MobileApiService.logout();
          if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
        }),
      ])));
'@
$s = Replace-Build $s '_ProfileInput' @'
    return AppInputField(label: hint, hintText: obscureText ? 'Enter password' : hint,
      controller: controller, isPassword: obscureText, keyboardType: keyboardType ?? TextInputType.text,
      textInputAction: textInputAction, textCapitalization: textCapitalization,
      maxLength: maxLength, onSubmitted: onSubmitted);
'@
$s = Replace-Build $s '_ProfileAction' @'
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Material(color: AppColors.surface,
      child: ListTile(onTap: onTap, leading: Icon(icon, color: icon == Icons.logout ? AppColors.primaryRed : AppColors.lightText),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, size: 20))));
'@
Write-Source $p $s

$p = 'lib/screens/shared/official_submission_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_SectionTitle' "    return AppSectionHeading(title: title, action: AppStatusBadge(label: '\$count'));".Replace('\', '$')
# Use a literal block for Dart interpolation.
$s = Replace-Build $s '_SectionTitle' @'
    return AppSectionHeading(title: title, action: AppStatusBadge(label: '$count'));
'@
$s = Replace-Build $s '_EmptyText' @'
    return AppEmptyState(icon: Icons.description_outlined, title: text,
      message: text.contains('active') ? 'New submission windows will appear here when opened by the federation.' : 'Choose an open submission window above to upload your PDF.');
'@
$s = Replace-Build $s '_SubmissionTile' @'
    final title = row['title']?.toString() ?? row['report_title']?.toString() ?? 'Submission';
    final status = row['status']?.toString() ?? 'submitted';
    final date = row['submitted_at']?.toString() ?? row['created_at']?.toString() ?? 'No date';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 6),
      Text(date, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 8),
      AppStatusBadge(label: status.replaceAll('_', ' '), color: status == 'rejected' ? AppColors.error : status == 'pending' ? AppColors.warning : AppColors.success),
      const Divider(height: 20),
    ]));
'@
$s = $s.Replace('          Row(', '          AppAdaptiveRow(')
$s = $s.Replace("child: const Text('Continue')", "child: const Text('Submit PDF')")
$s = $s.Replace("label: Text(_file?.name ?? 'Choose PDF file')", "label: Text(_isPickingFile ? 'Opening files…' : _file?.name ?? 'Choose PDF file')")
$s = $s.Replace("          DropdownButtonFormField<String>(", @'
          const AppSectionHeading(title: 'Submission details', subtitle: 'Select a reporting period, attach your PDF, and add any remarks.'),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
'@)
# The introductory text belongs only before the first picker.
$needle = "          const AppSectionHeading(title: 'Submission details', subtitle: 'Select a reporting period, attach your PDF, and add any remarks.'),`n          const SizedBox(height: 24),`n"
$first = $s.IndexOf($needle); if ($first -ge 0) { $tail = $s.Substring($first + $needle.Length).Replace($needle, ''); $s = $s.Substring(0, $first + $needle.Length) + $tail }
Write-Source $p $s

$p = 'lib/screens/sk_pres/president_leadership_screen.dart'; $s = Read-Source $p
$s = $s.Replace('icon: const Icon(Icons.person_add_alt_1, color: Colors.white)', "tooltip: 'Add council member',`n                      icon: const Icon(Icons.person_add_alt_1, color: AppColors.darkGray)")
$s = $s.Replace('leader.isExecutive ? AppColors.primaryRed : AppColors.gold', 'leader.isExecutive ? AppColors.primaryRed : AppColors.lightText')
$s = $s.Replace('color: AppColors.softPink,', 'color: AppColors.surface,')
$s = Replace-Build $s '_Section' @'
    return Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppSectionHeading(title: title, action: AppStatusBadge(label: '${leaders.length}')),
      const SizedBox(height: 12),
      if (leaders.isEmpty) AppEmptyState(icon: icon, title: emptyText, message: 'Council profiles will appear here when available.')
      else AppSurface(padding: EdgeInsets.zero, child: Column(children: [
        for (var i = 0; i < leaders.length; i++) ...[
          _LeaderCard(leader: leaders[i]),
          if (i < leaders.length - 1) const Divider(height: 1, indent: 64, endIndent: 16),
        ],
      ])),
    ]));
'@
Write-Source $p $s

$p = 'lib/screens/shared/native_agora_meeting_screen.dart'; $s = Read-Source $p
$s = $s.Replace('backgroundColor: AppColors.surface, foregroundColor: AppColors.darkGray,', 'backgroundColor: const Color(0xFF151B22), foregroundColor: Colors.white,')
$s = $s.Replace("_channel.isEmpty`r`n                        ? _status`r`n                        : '\$_status  |  \$_channel'", '_status')
$s = [regex]::Replace($s, "_channel\.isEmpty\s*\? _status\s*: '[^']*'", '_status')
$s = $s.Replace('                  Row(' + "`r`n" + '                    mainAxisAlignment: MainAxisAlignment.center,', '                  Wrap(' + "`r`n" + '                    alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,')
$s = $s.Replace('                      const SizedBox(width: 10),', '')
$s = $s.Replace('                left: 8,' + "`r`n" + '                bottom: 8,', '                left: 8,' + "`r`n" + '                right: 8,' + "`r`n" + '                bottom: 8,')
$s = $s.Replace('crossAxisCount: totalTiles <= 1 ? 1 : totalTiles <= 4 ? 2 : 3', 'crossAxisCount: totalTiles <= 1 ? 1 : 2')
Write-Source $p $s

$p = 'lib/widgets/notification_bell.dart'; $s = Read-Source $p
$s = $s.Replace('Icons.notifications_none_rounded, color: Colors.white', 'Icons.notifications_none_rounded, color: AppColors.darkGray')
$s = $s.Replace('color: Color(0xFFFFC107)', 'color: AppColors.primaryRed')
$s = $s.Replace('fontSize: 9,', 'fontSize: 11,')
$s = $s.Replace('const Expanded(child: Center(child: Text(''No notifications yet'')))', "const Expanded(child: Center(child: AppEmptyState(icon: Icons.notifications_none_outlined, title: 'You’re all caught up', message: 'New council updates will appear here.')))")
$s = $s.Replace('height: 420,', 'height: MediaQuery.sizeOf(context).height * .65,')
$s = $s.Replace('showDragHandle: true,', 'showDragHandle: true, isScrollControlled: true,')
$s = $s.Replace('separatorBuilder: (_, __)', 'separatorBuilder: (_, index)')
Write-Source $p $s

# Consistent recoverable sync errors without changing any network calls.
foreach ($p in @('lib/screens/shared/role_dashboard_screen.dart','lib/screens/shared/prototype_calendar_screen.dart','lib/screens/shared/rankings_screen.dart','lib/screens/shared/official_submission_screen.dart','lib/screens/shared/synced_data_screen.dart','lib/screens/sk_pres/president_reports_screen.dart','lib/screens/sk_pres/president_leadership_screen.dart','lib/screens/sk_pres/president_meetings_screen.dart')) {
  $s = Read-Source $p
  $s = $s.Replace('bool _isLoading = false;', "bool _isLoading = false;`n  String? _loadError;")
  $start = $s.IndexOf('  Future<void> _refresh()'); $end = $s.IndexOf("`n  }", $start) + 4
  $part = $s.Substring($start, $end - $start)
  $part = $part.Replace('setState(() => _isLoading = true);', 'setState(() { _isLoading = true; _loadError = null; });')
  $part = $part.Replace('if (mounted) _showMessage(exception.message);', 'if (mounted) setState(() => _loadError = exception.message);')
  if ($p.EndsWith('rankings_screen.dart')) {
    $part = [regex]::Replace($part, 'if \(mounted\) \{[\s\S]*?\n      \}', 'if (mounted) setState(() => _loadError = exception.message);')
  }
  $s = $s.Substring(0,$start) + $part + $s.Substring($end)
  $s = $s.Replace('if (_isLoading) const LinearProgressIndicator(minHeight: 3),', @'
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              if (_loadError != null) AppEmptyState(icon: Icons.cloud_off_outlined,
                title: 'Unable to refresh', message: 'Check your connection and try again. Previously loaded records may still be shown.', onAction: _refresh),
'@)
  Write-Source $p $s
}

# Fix text encoding introduced by Windows PowerShell's default script encoding.
Get-ChildItem (Join-Path $PSScriptRoot 'lib') -Recurse -Filter '*.dart' | ForEach-Object {
  $s = [IO.File]::ReadAllText($_.FullName)
  $s = $s.Replace('Â·', '·').Replace('â€¦', '…').Replace('Â°', '°')
  [IO.File]::WriteAllText($_.FullName, $s, $utf8)
}
