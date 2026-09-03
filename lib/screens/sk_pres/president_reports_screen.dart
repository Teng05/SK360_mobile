import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../utils/submitted_file_opener.dart';
import '../../widgets/president_components.dart';

class PresidentReportsScreen extends StatefulWidget {
  const PresidentReportsScreen({super.key});

  @override
  State<PresidentReportsScreen> createState() => _PresidentReportsScreenState();
}

class _PresidentReportsScreenState extends State<PresidentReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String _typeFilter = 'all';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    if (MobileApiService.syncedData == null) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = _filteredReports();
    final allReports = _allReports();
    final stats = _stats(allReports);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: null,
        onItemSelected: _handleNavSelection,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'View Reports',
                subtitle: 'Submitted documents',
                trailing: [
                  IconButton(
                    onPressed: _isLoading ? null : _refresh,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total',
                        value: '${stats.total}',
                        icon: Icons.folder_copy_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Reports',
                        value: '${stats.accomplishment}',
                        icon: Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Budgets',
                        value: '${stats.budget}',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Filters(
                  searchController: _searchController,
                  typeFilter: _typeFilter,
                  statusFilter: _statusFilter,
                  onTypeChanged: (value) {
                    setState(() => _typeFilter = value ?? 'all');
                  },
                  onStatusChanged: (value) {
                    setState(() => _statusFilter = value ?? 'all');
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No submitted reports found.',
                      style: TextStyle(color: AppColors.lightText),
                    ),
                  ),
                )
              else
                ...reports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: _ReportCard(
                      report: report,
                      onOpenFile: () => _openSubmittedFile(report),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ReportItem> _filteredReports() {
    final query = _searchController.text.trim().toLowerCase();

    return _allReports().where((report) {
      final matchesType = _typeFilter == 'all' || report.typeKey == _typeFilter;
      final matchesStatus =
          _statusFilter == 'all' || report.status.toLowerCase() == _statusFilter;
      final matchesSearch = query.isEmpty ||
          report.title.toLowerCase().contains(query) ||
          report.typeLabel.toLowerCase().contains(query) ||
          report.method.toLowerCase().contains(query) ||
          report.status.toLowerCase().contains(query) ||
          report.submittedAt.toLowerCase().contains(query) ||
          report.amount.toLowerCase().contains(query) ||
          report.fileLabel.toLowerCase().contains(query) ||
          report.submitter.toLowerCase().contains(query) ||
          report.role.toLowerCase().contains(query) ||
          report.barangay.toLowerCase().contains(query) ||
          report.period.toLowerCase().contains(query);

      return matchesType && matchesStatus && matchesSearch;
    }).toList();
  }

  List<_ReportItem> _allReports() {
    final data = MobileApiService.syncedData;
    if (data == null) return [];

    final barangays = <String, String>{};
    for (final row in (data['barangays'] as List<dynamic>? ?? [])) {
      final map = Map<String, dynamic>.from(row as Map);
      barangays['${map['barangay_id']}'] = map['barangay_name']?.toString() ?? '';
    }

    final items = <_ReportItem>[];
    final accomplishmentSources = <dynamic>[
      ...(data['report_submissions'] as List<dynamic>? ?? []),
      ...(data['accomplishment_reports'] as List<dynamic>? ?? []),
    ];

    for (final row in accomplishmentSources) {
      final map = Map<String, dynamic>.from(row as Map);
      items.add(
        _ReportItem(
          typeKey: 'accomplishment',
          typeLabel: 'Accomplishment Report',
          title: _firstValue(map, ['report_title', 'title'], 'Untitled report'),
          barangay: _barangayLabel(map, barangays),
          period: _reportPeriod(map),
          method: _readable(_firstValue(map, ['submission_method'], 'File')),
          status: _firstValue(map, ['status'], 'submitted'),
          submittedAt: _firstValue(map, ['submitted_at', 'created_at'], 'No date'),
          submitter: _submitterLabel(map),
          role: _firstValue(map, ['role', 'user_role', 'submitted_by_role'], ''),
          fileLabel: _firstValue(
            map,
            [
              'uploaded_file_name',
              'report_file_path',
              'uploaded_file_path',
              'generated_pdf_path',
            ],
            'Report document',
          ),
          fileUrl: _documentUrl(map, 'accomplishment_report'),
        ),
      );
    }

    for (final row in (data['budget_reports'] as List<dynamic>? ?? [])) {
      final map = Map<String, dynamic>.from(row as Map);
      items.add(
        _ReportItem(
          typeKey: 'budget',
          typeLabel: 'Budget Report',
          title: _firstValue(map, ['title', 'document_type'], 'Budget document'),
          barangay: _barangayLabel(map, barangays),
          period: _budgetPeriod(map),
          method: _readable(_firstValue(map, ['submission_method'], 'Template')),
          status: _firstValue(map, ['status'], 'submitted'),
          submittedAt: _firstValue(map, ['submitted_at', 'created_at'], 'No date'),
          submitter: _submitterLabel(map),
          role: _firstValue(map, ['role', 'user_role', 'submitted_by_role'], ''),
          amount: _firstValue(map, ['total_amount'], ''),
          fileLabel: _firstValue(
            map,
            ['uploaded_file_name', 'generated_pdf_path', 'uploaded_file_path'],
            'Budget document',
          ),
          fileUrl: _documentUrl(map, 'budget_report'),
        ),
      );
    }

    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  _ReportStats _stats(List<_ReportItem> reports) {
    return _ReportStats(
      total: reports.length,
      accomplishment: reports.where((item) => item.typeKey == 'accomplishment').length,
      budget: reports.where((item) => item.typeKey == 'budget').length,
    );
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    handleRoleNavSelection(context, item);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }

  Future<void> _openSubmittedFile(_ReportItem report) async {
    final url = _absoluteFileUrl(report.fileUrl);
    if (url.isEmpty) {
      _showMessage('No submitted file is available for this report.');
      return;
    }

    final result = await SubmittedFileOpener.open(url);
    if (!result.opened) {
      _showMessage(result.message ?? 'Unable to open submitted file.');
    }
  }
}

class _Filters extends StatelessWidget {
  final TextEditingController searchController;
  final String typeFilter;
  final String statusFilter;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStatusChanged;

  const _Filters({
    required this.searchController,
    required this.typeFilter,
    required this.statusFilter,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: _inputDecoration(
              'Search reports',
              Icons.search,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: typeFilter,
                  decoration: _fieldDecoration('Type'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                      value: 'accomplishment',
                      child: Text('Accomplishment'),
                    ),
                    DropdownMenuItem(value: 'budget', child: Text('Budget')),
                  ],
                  onChanged: onTypeChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  decoration: _fieldDecoration('Status'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                    DropdownMenuItem(value: 'recorded', child: Text('Recorded')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _ReportItem report;
  final VoidCallback onOpenFile;

  const _ReportCard({required this.report, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    final isBudget = report.typeKey == 'budget';
    final statusColor = _statusColor(report.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isBudget ? const Color(0xFFE8F5E9) : AppColors.softPink,
                child: Icon(
                  isBudget
                      ? Icons.account_balance_wallet_outlined
                      : Icons.receipt_long,
                  color: isBudget ? Colors.green : AppColors.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${report.typeLabel} - ${report.period}',
                      style: const TextStyle(
                        color: AppColors.lightText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(_readable(report.status)),
                labelStyle: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Line(icon: Icons.location_on_outlined, text: report.barangay),
          _Line(icon: Icons.upload_file_outlined, text: report.method),
          _Line(icon: Icons.schedule_outlined, text: report.submittedAt),
          if (report.amount.isNotEmpty)
            _Line(icon: Icons.payments_outlined, text: 'Total amount: ${report.amount}'),
          if (report.fileUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Material(
              color: AppColors.softPink,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onOpenFile,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: AppColors.primaryRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.fileLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.darkGray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        color: AppColors.primaryRed,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.lightText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.lightText, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportItem {
  final String typeKey;
  final String typeLabel;
  final String title;
  final String barangay;
  final String period;
  final String method;
  final String status;
  final String submittedAt;
  final String submitter;
  final String role;
  final String amount;
  final String fileLabel;
  final String fileUrl;

  const _ReportItem({
    required this.typeKey,
    required this.typeLabel,
    required this.title,
    required this.barangay,
    required this.period,
    required this.method,
    required this.status,
    required this.submittedAt,
    this.submitter = '',
    this.role = '',
    this.amount = '',
    required this.fileLabel,
    required this.fileUrl,
  });
}

class _ReportStats {
  final int total;
  final int accomplishment;
  final int budget;

  const _ReportStats({
    required this.total,
    required this.accomplishment,
    required this.budget,
  });
}

InputDecoration _inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.lightText),
    filled: true,
    fillColor: AppColors.softPink,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.softPink,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}

String _firstValue(
  Map<String, dynamic> row,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }

  return fallback;
}

String _barangayLabel(Map<String, dynamic> row, Map<String, String> barangays) {
  final explicit = _firstValue(row, ['barangay_name', 'barangay'], '');
  if (explicit.isNotEmpty) return 'Barangay $explicit';

  final id = row['barangay_id']?.toString();
  final name = id == null ? null : barangays[id];
  if (name != null && name.isNotEmpty) return 'Barangay $name';

  return 'Barangay not specified';
}

String _submitterLabel(Map<String, dynamic> row) {
  final explicit = _firstValue(
    row,
    ['submitter_name', 'submitted_by_name', 'user_name', 'author_name', 'name'],
    '',
  );
  if (explicit.isNotEmpty) return explicit;

  final first = _firstValue(row, ['first_name'], '');
  final last = _firstValue(row, ['last_name'], '');
  final combined = [first, last].where((part) => part.isNotEmpty).join(' ');
  if (combined.isNotEmpty) return combined;

  return _firstValue(row, ['email', 'submitted_by', 'user_id'], '');
}

String _reportPeriod(Map<String, dynamic> row) {
  final type = _firstValue(row, ['report_type'], '');
  final year = _firstValue(row, ['reporting_year'], '');
  final month = _firstValue(row, ['reporting_month'], '');
  final quarter = _firstValue(row, ['reporting_quarter'], '');
  final period = _firstValue(row, ['reporting_period'], '');

  if (period.isNotEmpty) return period;
  if (type == 'monthly' && month.isNotEmpty && year.isNotEmpty) {
    return 'Monthly $month/$year';
  }
  if (type == 'quarterly' && quarter.isNotEmpty && year.isNotEmpty) {
    return '$quarter $year';
  }
  if (type == 'annual' && year.isNotEmpty) return 'Annual $year';

  return type.isEmpty ? 'No period' : _readable(type);
}

String _budgetPeriod(Map<String, dynamic> row) {
  final type = _firstValue(row, ['budget_period_type', 'document_type'], '');
  final year = _firstValue(row, ['fiscal_year'], '');
  final month = _firstValue(row, ['fiscal_month'], '');
  final quarter = _firstValue(row, ['fiscal_quarter'], '');

  if (type == 'monthly' && month.isNotEmpty && year.isNotEmpty) {
    return 'Monthly $month/$year';
  }
  if (type == 'quarterly' && quarter.isNotEmpty && year.isNotEmpty) {
    return '$quarter $year';
  }
  if (type == 'annual' && year.isNotEmpty) return 'Annual $year';
  if (year.isNotEmpty) return year;

  return type.isEmpty ? 'No period' : _readable(type);
}

String _readable(String value) {
  final words = value.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String _absoluteFileUrl(String value) {
  final path = value.trim();
  if (path.isEmpty) return '';
  if (!path.contains('/') && !path.contains(r'\')) return '';
  final uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme) return path;

  final base = Uri.parse(MobileApiService.baseUrl);
  final origin = '${base.scheme}://${base.authority}';
  return '$origin/${path.replaceFirst(RegExp(r'^/+'), '')}';
}

String _documentUrl(Map<String, dynamic> row, String sourceType) {
  final uploaded = _firstUsablePath(row, [
    'report_file_url',
    'uploaded_file_url',
    'report_file_path',
    'uploaded_file_path',
  ]);
  if (uploaded.isNotEmpty) return uploaded;

  final generated = _firstUsablePath(row, [
    'generated_pdf_url',
    'generated_pdf_path',
  ]);
  if (generated.isNotEmpty) return generated;

  final sourceId = sourceType == 'budget_report'
      ? _firstValue(row, ['budget_report_id'], '')
      : _firstValue(row, ['report_id'], '');
  final marker = _firstValue(row, ['generated_pdf_path'], '');
  if (sourceId.isNotEmpty && _isGeneratedMarker(marker)) {
    return _archiveDownloadUrl(sourceType, sourceId);
  }

  return '';
}

String _firstUsablePath(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && !_isGeneratedMarker(value)) {
      return value;
    }
  }

  return '';
}

bool _isGeneratedMarker(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized == 'SYSTEM_GEN' || normalized == 'TEMPLATE_GEN';
}

String _archiveDownloadUrl(String sourceType, String sourceId) {
  final base = Uri.parse(MobileApiService.baseUrl);
  return '${base.scheme}://${base.authority}/sk_pres/archive/download/$sourceType/$sourceId';
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'submitted':
    case 'recorded':
    case 'approved':
      return Colors.green;
    case 'rejected':
      return AppColors.primaryRed;
    case 'draft':
      return Colors.blueGrey;
    default:
      return const Color(0xFFFF9800);
  }
}
