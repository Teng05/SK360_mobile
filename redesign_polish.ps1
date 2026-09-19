$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Read-Source([string]$path) { [IO.File]::ReadAllText((Join-Path $PSScriptRoot $path)) }
function Write-Source([string]$path, [string]$text) { [IO.File]::WriteAllText((Join-Path $PSScriptRoot $path), $text, $utf8) }
function Replace-Build([string]$text, [string]$class, [string]$body) {
  $start = $text.IndexOf('class ' + $class + ' ')
  $start = $text.IndexOf('Widget build(BuildContext context) {', $start)
  $open = $text.IndexOf('{', $start); $depth = 1; $end = $open + 1
  while ($depth -gt 0) { if ($text[$end] -eq '{') { $depth++ }; if ($text[$end] -eq '}') { $depth-- }; $end++ }
  return $text.Substring(0, $open + 1) + "`n" + $body + "`n  }" + $text.Substring($end)
}
$p = 'lib/screens/sk_pres/president_reports_screen.dart'; $s = Read-Source $p
$s = Replace-Build $s '_ReportCard' @'
    final isBudget = report.typeKey == 'budget';
    return AppSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        AppStatusBadge(label: isBudget ? 'Budget' : 'Accomplishment', color: AppColors.lightText),
        AppStatusBadge(label: _readable(report.status), color: _statusColor(report.status)),
      ]),
      const SizedBox(height: 14), Text(report.title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4), Text(report.period, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      _Line(icon: Icons.location_on_outlined, text: report.barangay),
      _Line(icon: Icons.upload_file_outlined, text: report.method),
      _Line(icon: Icons.schedule_outlined, text: report.submittedAt),
      if (report.amount.isNotEmpty) _Line(icon: Icons.payments_outlined, text: 'Total amount: ${report.amount}'),
      if (report.fileUrl.isNotEmpty) ...[
        const Divider(),
        ListTile(contentPadding: EdgeInsets.zero, onTap: onOpenFile,
          leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryRed),
          title: Text(report.fileLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: const Text('Open submitted document'),
          trailing: const Icon(Icons.open_in_new, size: 18)),
      ],
    ]));
'@
$s = [regex]::Replace($s, "const Padding\(\s*padding: EdgeInsets.all\(24\),\s*child: Center\(\s*child: Text\(\s*'No submitted reports found.',\s*style: TextStyle\(color: AppColors.lightText\),\s*\),\s*\),\s*\)", "const AppEmptyState(icon: Icons.description_outlined, title: 'No reports to show', message: 'Try a different search or report type. New submissions will appear here.')")
Write-Source $p $s

foreach ($p in @('lib/screens/sk_pres/consolidation_screen.dart','lib/screens/sk_pres/module_management_screen.dart')) {
  $s = Read-Source $p
  $loader = if ($p.Contains('consolidation')) { '_loadConsolidation' } else { '_loadSlots' }
  $s = $s.Replace('bool _isLoading = false;', "bool _isLoading = false;`n  String? _loadError;")
  $start = $s.IndexOf('  Future<void> ' + $loader + '()'); $end = $s.IndexOf("`n  }", $start) + 4
  $part = $s.Substring($start, $end - $start)
  $part = $part.Replace('setState(() => _isLoading = true);', 'setState(() { _isLoading = true; _loadError = null; });')
  $part = $part.Replace('if (mounted) _showMessage(exception.message);', 'if (mounted) setState(() => _loadError = exception.message);')
  $s = $s.Substring(0,$start) + $part + $s.Substring($end)
  $s = $s.Replace('if (_isLoading) const LinearProgressIndicator(minHeight: 3),', "if (_isLoading) const LinearProgressIndicator(minHeight: 3),`n              if (_loadError != null) AppEmptyState(icon: Icons.cloud_off_outlined, title: 'Unable to refresh', message: 'Check your connection and try again.', onAction: $loader),")
  if ($p.Contains('consolidation')) {
    $s = [regex]::Replace($s, "const Padding\(\s*padding: EdgeInsets.all\(24\),\s*child: Center\(\s*child: Text\(\s*'No barangay records found.',\s*style: TextStyle\(color: AppColors.lightText\),\s*\),\s*\),\s*\)", "const AppEmptyState(icon: Icons.folder_copy_outlined, title: 'No records for this period', message: 'Choose another reporting period or pull down to refresh.')")
    $s = [regex]::Replace($s, '\r?\n  void _showMessage\(String message\) \{[\s\S]*?\r?\n  \}', '')
  } else {
    $s = [regex]::Replace($s, "const Padding\(\s*padding: EdgeInsets.all\(24\),\s*child: Center\(\s*child: Text\(\s*'No submission slots yet.',\s*style: TextStyle\(color: AppColors.lightText\),\s*\),\s*\),\s*\)", "const AppEmptyState(icon: Icons.folder_open_outlined, title: 'Ready for your first submission window', message: 'Use Create Slot to set a report type, target role, and deadline.')")
    $s = $s.Replace("'${slot['submission_type']} - ${slot['role']}'", "'${slot['submission_type']} - ${slot['role']}'")
  }
  Write-Source $p $s
}

$p = 'lib/screens/shared/synced_data_screen.dart'; $s = Read-Source $p
$s = $s.Replace('synced item', 'published update').Replace("'Synced item'", "'Council update'")
$s = $s.Replace('maxLines: 3,' + "`r`n" + '              overflow: TextOverflow.ellipsis,', '')
Write-Source $p $s

Get-ChildItem (Join-Path $PSScriptRoot 'lib/screens') -Recurse -Filter '*.dart' | ForEach-Object {
  $s = [IO.File]::ReadAllText($_.FullName)
  $s = $s.Replace('Colors.green', 'AppColors.success').Replace('AppColors.successAccent', 'Colors.greenAccent').Replace('Colors.orange', 'AppColors.warning')
  $s = $s.Replace('SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed)', 'SnackBar(content: Text(message))')
  $s = $s.Replace('const LinearProgressIndicator(minHeight: 3)', 'const AppLoadingIndicator()')
  if ($s.Contains('String? _loadError;')) {
    $s = [regex]::Replace($s, 'if \((rows|reports|rankings|_slots|_submissions)\.isEmpty\)', 'if ($1.isEmpty && !_isLoading && _loadError == null)')
  }
  [IO.File]::WriteAllText($_.FullName, $s, $utf8)
}
