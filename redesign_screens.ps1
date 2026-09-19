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

# Consolidate the repeated visual overrides, without changing data or API code.
Get-ChildItem (Join-Path $PSScriptRoot 'lib/screens') -Recurse -Filter '*.dart' | ForEach-Object {
  $s = [IO.File]::ReadAllText($_.FullName)
  $s = [regex]::Replace($s, 'fontSize: (8|9|10|11|12)(?![\d.])', 'fontSize: 13')
  $s = $s.Replace('fillColor: AppColors.softPink', 'fillColor: AppColors.field')
  $s = [regex]::Replace($s, '(const )?Color\(0xFF(ECEFF3|E5E7EB|EDEDED|DDE2EA|E4E9FF)\)', 'AppColors.border')
  $s = [regex]::Replace($s, '(const )?Color\(0xFF(94A3B8|64748B|6B7280)\)', 'AppColors.lightText')
  $s = [regex]::Replace($s, '(const )?Color\(0xFF(F10612|0F5BFF)\)', 'AppColors.primaryRed')
  $s = [regex]::Replace($s, '(const )?Color\(0xFF(F8FAFF|EAF2FF|F2F0FF|F2F6FB)\)', 'AppColors.field')
  $s = [regex]::Replace($s, '(const )?Color\(0xFF(DFF8EA|E8F5E9)\)', 'AppColors.successSurface')
  $s = [regex]::Replace($s, '(const )?Color\(0xFF(009E4D|22C55E)\)', 'AppColors.success')
  $s = $s.Replace('Colors.green,', 'AppColors.success,').Replace('Colors.orange,', 'AppColors.warning,')
  $s = $s.Replace('const Color(0xFFFF9800)', 'AppColors.warning')
  $s = [regex]::Replace($s, '(const )?Color\(0xFF(FFC107|FFD54F|FFCA28)\)', 'AppColors.gold')
  $s = [regex]::Replace($s, '\s*boxShadow: \[\s*BoxShadow\([\s\S]*?\),\s*\],', '')
  # Use the app bar theme on full-screen forms, leaving call screens dark later.
  $s = [regex]::Replace($s, '(appBar: AppBar\([\s\S]*?)backgroundColor: AppColors.primaryRed,\s*foregroundColor: Colors.white,', '$1backgroundColor: AppColors.surface, foregroundColor: AppColors.darkGray,')
  # Dropdowns must constrain long barangay/role labels on phones.
  $s = [regex]::Replace($s, '(DropdownButtonFormField<[^>]+>\()(?!\s*isExpanded:)', '$1' + "`n          isExpanded: true,")
  # Remove duplicate isExpanded properties on the existing history picker.
  $s = [regex]::Replace($s, '(isExpanded: true,[\s\S]*?initialValue:[^\n]+\n)\s*isExpanded: true,', '$1')
  $s = $s.Replace('preferredSize: const Size.fromHeight(86)', 'preferredSize: const Size.fromHeight(92)')
  # Always allow pull-to-refresh even when there are only a few records.
  $s = [regex]::Replace($s, '(child: ListView\(\s*)(?!physics:)', '$1physics: const AlwaysScrollableScrollPhysics(),' + "`n")
  [IO.File]::WriteAllText($_.FullName, $s, $utf8)
}

$p = 'lib/screens/shared/role_dashboard_screen.dart'; $s = Read-Source $p
$s = $s.Replace("title: 'SK 360',", "title: 'SK 360°',").Replace("title: 'Engagement',", "title: 'Community posts',").Replace("title: 'Active Users',", "title: 'Barangays',")
$s = $s.Replace("caption: 'posts',", "caption: 'Shared updates',").Replace("caption: 'barangays',", "caption: 'Connected councils',")
$s = $s.Replace("if (_user['role']?.toString() == 'sk_president')", '')
$s = $s.Replace('const EdgeInsets.fromLTRB(16, 12, 16, 0)', 'const EdgeInsets.fromLTRB(20, 20, 20, 0)')
$s = $s.Replace('if (_isLoading) const LinearProgressIndicator(minHeight: 3),', @'
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, ${_user['first_name'] ?? 'SK official'}', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  const Text('Stay on top of your council’s work.', style: TextStyle(color: AppColors.lightText, fontSize: 15)),
                ],
              )),
'@)
$s = Replace-Build $s '_StatCard' @'
    return AppStatistic(label: title, value: value, icon: icon);
'@
$s = Replace-Build $s '_QuickActions' @'
    final official = MobileApiService.currentUser?['role'] != 'sk_president';
    final actions = [
      (official ? AppRoutes.reports : AppRoutes.moduleManagement, official ? 'Submit a report' : 'Submission slots', Icons.description_outlined),
      (official ? AppRoutes.budget : AppRoutes.consolidation, official ? 'Budget reports' : 'Consolidation', Icons.account_balance_wallet_outlined),
      (AppRoutes.videoMeetings, 'Video meetings', Icons.videocam_outlined),
      (AppRoutes.announcements, 'Announcements', Icons.campaign_outlined),
      (AppRoutes.rankings, 'Rankings', Icons.emoji_events_outlined),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppSectionHeading(title: 'Your workspace'), const SizedBox(height: 12),
      AppSurface(padding: EdgeInsets.zero, child: Column(children: [
        for (var i = 0; i < actions.length; i++) ...[
          ListTile(onTap: () => onOpen(actions[i].$1),
            leading: Icon(actions[i].$3, color: AppColors.primaryRed, size: 22),
            title: Text(actions[i].$2, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, size: 20)),
          if (i < actions.length - 1) const Divider(height: 1, indent: 56, endIndent: 16),
        ],
      ])),
    ]);
'@
$s = Replace-Build $s '_UpcomingMeetingsCard' @'
    final visible = meetings.where(_isUpcomingMeeting).toList()..sort(_compareMeetings);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppSectionHeading(title: 'Coming up', action: TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.videoMeetings), child: const Text('View all'))),
      const SizedBox(height: 8),
      if (visible.isEmpty) const AppSurface(child: Row(children: [
        Icon(Icons.event_available_outlined, color: AppColors.lightText), SizedBox(width: 12),
        Expanded(child: Text('No upcoming meetings. Check your calendar for activities and deadlines.', style: TextStyle(color: AppColors.lightText))),
      ])) else ...visible.take(2).map((meeting) => _MeetingTile(row: meeting)),
    ]);
'@
$s = Replace-Build $s '_FeedSection' @'
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 8), child: AppSectionHeading(title: 'Community updates')),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [for (var i = 0; i < tabs.length; i++) Padding(
          padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(tabs[i]),
            selected: i == activeTab, onSelected: (_) => onTabSelected(i), showCheckmark: false)),
        ])),
      const SizedBox(height: 12),
      if (posts.isEmpty) const AppEmptyState(icon: Icons.forum_outlined, title: 'No updates here yet',
        message: 'Share a council update above or choose another category.')
      else ...posts.map((post) => _PostCard(row: post, onLike: onLike)),
    ]);
'@
$s = Replace-Build $s '_PostCard' @'
    final author = row['author_name']?.toString() ?? 'SK 360 User';
    final category = row['title']?.toString() ?? 'Update';
    final content = row['content']?.toString() ?? '';
    final date = row['created_at']?.toString() ?? '';
    final likes = row['likes_count']?.toString() ?? '0';
    final liked = row['liked_by_current_user'] == true || row['liked_by_current_user'] == 1;
    return Container(padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(backgroundColor: AppColors.field, child: Icon(Icons.person_outline, color: AppColors.lightText)),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(author, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2), Text(date, style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
        const SizedBox(height: 12), AppStatusBadge(label: category, color: AppColors.primaryRed),
        const SizedBox(height: 12), Text(content, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        TextButton.icon(onPressed: () => onLike(row), icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
          label: Text('$likes ${liked ? 'Liked' : 'Like'}'),
          style: TextButton.styleFrom(foregroundColor: liked ? AppColors.primaryRed : AppColors.lightText)),
      ]));
'@
$s = Replace-Build $s '_Panel' '    return AppSurface(child: child);'
$s = $s.Replace("'Shared Wall'", "'Share an update'")
# The composer has long category names; stack it on narrow phones.
$start = $s.IndexOf('class _SharedWallComposerState'); $end = $s.IndexOf('class _FeedSection')
$part = $s.Substring($start, $end - $start)
$part = $part.Replace('          Row(', '          AppAdaptiveRow(')
$s = $s.Substring(0, $start) + $part + $s.Substring($end)
Write-Source $p $s

$p = 'lib/screens/shared/prototype_calendar_screen.dart'; $s = Read-Source $p
$s = $s.Replace("import '../../routes.dart';", '')
$s = Replace-Build $s '_HeroCard' @'
    return const AppSectionHeading(title: 'Make room for what matters', subtitle: 'Meetings, activities, and submission dates in one place.');
'@
$s = Replace-Build $s '_CalendarPanel' '    return AppSurface(child: child);'
$s = $s.Replace("'+ Schedule New Event'", "'Schedule event'")
$s = $s.Replace('onPressed: onPrevious,', "tooltip: 'Previous month',`n                onPressed: onPrevious,")
$s = $s.Replace('onPressed: onNext,', "tooltip: 'Next month',`n                onPressed: onNext,")
$s = $s.Replace('crossAxisCount: 7,', "crossAxisCount: 7,`n              mainAxisExtent: 48,")
$s = $s.Replace('margin: const EdgeInsets.all(4)', 'margin: const EdgeInsets.all(2)')
$s = $s.Replace('                Row(', '                AppAdaptiveRow(')
# Do not reserve a large fixed empty area below each date.
$start = $s.IndexOf('class _EventsForDateCard'); $end = $s.IndexOf('class _AllEventsCard')
$part = $s.Substring($start, $end - $start)
$part = [regex]::Replace($part, 'const SizedBox\(\s*height: 120,[\s\S]*?\n            \)\n          else', "const AppEmptyState(icon: Icons.event_available_outlined, title: 'No events on this day', message: 'Select another date to see its schedule.')`n          else")
$s = $s.Substring(0, $start) + $part + $s.Substring($end)
$s = $s.Replace('width: 36,', 'width: 48,')
Write-Source $p $s

# Shared summary and surface components replace repeated one-off widgets.
foreach ($p in @('lib/screens/sk_pres/president_reports_screen.dart', 'lib/screens/sk_pres/president_leadership_screen.dart')) {
  $s = Read-Source $p
  $s = Replace-Build $s '_SummaryCard' '    return AppStatistic(label: label, value: value, icon: icon);'
  Write-Source $p $s
}
foreach ($p in @('lib/screens/shared/official_submission_screen.dart', 'lib/screens/shared/rankings_screen.dart', 'lib/screens/sk_pres/president_meetings_screen.dart')) {
  $s = Read-Source $p
  $s = Replace-Build $s '_Panel' '    return AppSurface(child: child);'
  Write-Source $p $s
}
$p = 'lib/screens/sk_pres/module_management_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_SummaryCard' '    return AppStatistic(label: label, value: value);'
$s = Replace-Build $s '_SubmissionMessage' @'
    return AppEmptyState(icon: onRetry == null ? Icons.folder_open_outlined : Icons.cloud_off_outlined,
      title: onRetry == null ? 'No submissions to show' : 'Unable to load submissions', message: message, onAction: onRetry);
'@
$s = $s.Replace("'${slot['submission_type']} - ${slot['role']}'", "'${slot['submission_type']} - ${slot['role']}'")
$s = $s.Replace("'View Barangays'", "'Submissions'")
$s = $s.Replace('                Row(', '                AppAdaptiveRow(')
$s = $s.Replace('          Row(' + "`r`n" + '            children: [' + "`r`n" + '              Expanded(', '          AppAdaptiveRow(' + "`r`n" + '            children: [' + "`r`n" + '              Expanded(')
$s = $s.Replace('onPressed: onDelete,', "tooltip: 'Delete submission slot',`n            onPressed: onDelete,")
Write-Source $p $s
$p = 'lib/screens/sk_pres/consolidation_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_Stat' '    return AppStatistic(label: label, value: value, color: color);'
$s = $s.Replace('color: AppColors.gold', 'color: AppColors.warning')
$s = $s.Replace('color: submitted ? Colors.green : AppColors.borderPink', 'color: AppColors.border')
$s = [regex]::Replace($s, 'Chip\(\s*label: Text\(submitted \? ''Submitted'' : ''Pending''\),\s*backgroundColor:[\s\S]*?\),', "AppStatusBadge(label: submitted ? 'Submitted' : 'Pending', color: submitted ? AppColors.success : AppColors.warning),")
$s = $s.Replace('          Row(', '          AppAdaptiveRow(')
Write-Source $p $s
$p = 'lib/screens/sk_pres/president_meetings_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_StatCard' '    return AppStatistic(label: label, value: value);'
$s = Replace-Build $s '_StatusChip' '    return AppStatusBadge(label: label, color: active ? AppColors.success : AppColors.lightText);'
$s = $s.Replace("'Create and join web meetings'", "'Connect with your council'")
$s = $s.Replace('title.toUpperCase()', 'title').Replace('fontSize: 13,' + "`r`n" + '                letterSpacing: 0.8,', 'fontSize: 17,')
Write-Source $p $s

$p = 'lib/screens/shared/rankings_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_TopThreeSection' @'
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppSectionHeading(title: 'Top barangays'), const SizedBox(height: 12),
      for (var i = 0; i < rankings.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8),
        child: _TopRankCard(item: rankings[i], place: i + 1)),
      if (rankings.isEmpty) const Text('No results for this period.', style: TextStyle(color: AppColors.lightText)),
    ]);
'@
$s = Replace-Build $s '_TopRankCard' @'
    if (item == null) return const SizedBox.shrink();
    return AppSurface(child: Row(children: [
      Container(width: 44, height: 44, alignment: Alignment.center,
        decoration: BoxDecoration(color: place == 1 ? AppColors.warningSurface : AppColors.field, borderRadius: BorderRadius.circular(10)),
        child: Text('#${item!.rank}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
          color: place == 1 ? AppColors.warning : AppColors.lightText))),
      const SizedBox(width: 12), Expanded(child: Text(item!.name, style: Theme.of(context).textTheme.titleSmall)),
      const SizedBox(width: 8), Text('${item!.points} pts', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryRed)),
    ]));
'@
$s = Replace-Build $s '_SectionLabel' '    return AppSectionHeading(title: label);'
$s = Replace-Build $s '_EmptyRankingState' @'
    return const AppEmptyState(icon: Icons.emoji_events_outlined, title: 'Rankings are on their way',
      message: 'Barangay results will appear when they are published. Pull down to refresh.');
'@
$s = $s.Replace('SizedBox(' + "`r`n" + '            height: 520,', 'SizedBox(').Replace('SizedBox(' + "`n" + '            height: 520,', 'SizedBox(')
$s = $s.Replace('primary: false,', "primary: false,`n                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),")
$s = $s.Replace('width: 62,', 'width: 78,').Replace('width: 34,', 'width: 44,')
Write-Source $p $s

$p = 'lib/screens/shared/synced_data_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_HeaderCard' '    return AppSectionHeading(title: title, subtitle: subtitle);'
$s = Replace-Build $s '_EmptyState' '    return AppEmptyState(icon: icon, title: title, message: message);'
$s = $s.Replace("'${rows.length} synced item${rows.length == 1 ? '' : 's'}'", "'${rows.length} synced item${rows.length == 1 ? '' : 's'}'")
$s = $s.Replace("'Pull to refresh after data is added in the web app.'", "'Published updates will appear here. Pull down to refresh.'")
$s = $s.Replace('FloatingActionButton(', 'FloatingActionButton.extended(').Replace('child: const Icon(Icons.add),', "icon: const Icon(Icons.add), label: const Text('New post'),")
$s = $s.Replace('padding: const EdgeInsets.only(bottom: 24)', 'padding: const EdgeInsets.only(bottom: 96)')
# Let readers see complete announcements instead of truncating the only copy.
$s = $s.Replace('              maxLines: 3,' + "`r`n" + '              overflow: TextOverflow.ellipsis,', '')
Write-Source $p $s
