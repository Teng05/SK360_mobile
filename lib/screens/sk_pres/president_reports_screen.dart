import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../utils/submitted_file_opener.dart';
import '../../widgets/president_components.dart';

class PresidentReportsScreen extends StatefulWidget {
  const PresidentReportsScreen({super.key});

  @override
  State<PresidentReportsScreen> createState() => _PresidentReportsScreenState();
}

class _PresidentReportsScreenState extends State<PresidentReportsScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _loadError;
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() => setState(() {}));
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'View Reports',
                subtitle: 'Submitted documents',
              ),
              if (_isLoading) const AppLoadingIndicator(),
              if (_loadError != null)
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to refresh',
                  message:
                      'Check your connection and try again. Previously loaded records may still be shown.',
                  onAction: _refresh,
                ),
              const AppPageIntro(
                eyebrow: 'Federation archive',
                title: 'View Reports',
                subtitle:
                    'Accomplishment and budget documents submitted by '
                    'barangay councils.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: AppMetricGrid(
                  columns: 3,
                  children: [
                    _SummaryCard(
                      label: 'Total',
                      value: '${stats.total}',
                      icon: Icons.folder_copy_outlined,
                      color: AppColors.primaryRed,
                    ),
                    _SummaryCard(
                      label: 'Reports',
                      value: '${stats.accomplishment}',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.success,
                    ),
                    _SummaryCard(
                      label: 'Budgets',
                      value: '${stats.budget}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: _Filters(
                  searchController: _searchController,
                  typeFilter: _typeFilter,
                  onTypeChanged: (value) {
                    setState(() => _typeFilter = value ?? 'all');
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (reports.isEmpty && !_isLoading && _loadError == null)
                const AppEmptyState(
                  icon: Icons.description_outlined,
                  title: 'No reports to show',
                  message:
                      'Try a different search or report type. New submissions will appear here.',
                )
              else
                ...reports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
      final matchesSearch =
          query.isEmpty ||
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

      return matchesType && matchesSearch;
    }).toList();
  }

  List<_ReportItem> _allReports() {
    final data = MobileApiService.syncedData;
    if (data == null) return [];

    final barangays = <String, String>{};
    for (final row in (data['barangays'] as List<dynamic>? ?? [])) {
      final map = Map<String, dynamic>.from(row as Map);
      barangays['${map['barangay_id']}'] =
          map['barangay_name']?.toString() ?? '';
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
          submittedAt: _firstValue(map, [
            'submitted_at',
            'created_at',
          ], 'No date'),
          submitter: _submitterLabel(map),
          role: _firstValue(map, [
            'role',
            'user_role',
            'submitted_by_role',
          ], ''),
          fileLabel: _firstValue(map, [
            'uploaded_file_name',
            'report_file_path',
            'uploaded_file_path',
            'generated_pdf_path',
          ], 'Report document'),
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
          title: _firstValue(map, [
            'title',
            'document_type',
          ], 'Budget document'),
          barangay: _barangayLabel(map, barangays),
          period: _budgetPeriod(map),
          method: _readable(
            _firstValue(map, ['submission_method'], 'Template'),
          ),
          status: _firstValue(map, ['status'], 'submitted'),
          submittedAt: _firstValue(map, [
            'submitted_at',
            'created_at',
          ], 'No date'),
          submitter: _submitterLabel(map),
          role: _firstValue(map, [
            'role',
            'user_role',
            'submitted_by_role',
          ], ''),
          amount: _firstValue(map, ['total_amount'], ''),
          fileLabel: _firstValue(map, [
            'uploaded_file_name',
            'generated_pdf_path',
            'uploaded_file_path',
          ], 'Budget document'),
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
      accomplishment: reports
          .where((item) => item.typeKey == 'accomplishment')
          .length,
      budget: reports.where((item) => item.typeKey == 'budget').length,
    );
  }

  Future<void> _refresh() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _loadError = exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    handleRoleNavSelection(context, item);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
  final ValueChanged<String?> onTypeChanged;

  const _Filters({
    required this.searchController,
    required this.typeFilter,
    required this.onTypeChanged,
  });

  static const _values = ['all', 'accomplishment', 'budget'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: searchController,
          hintText: 'Search reports, barangays, or periods…',
        ),
        const SizedBox(height: 12),
        AppFilterPills(
          padding: EdgeInsets.zero,
          labels: const ['All', 'Report Submissions', 'Budget Reports'],
          selectedIndex: _values.indexOf(typeFilter).clamp(0, 2),
          onSelected: (index) => onTypeChanged(_values[index]),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatistic(label: label, value: value, icon: icon, color: color);
  }
}

class _ReportCard extends StatelessWidget {
  final _ReportItem report;
  final VoidCallback onOpenFile;

  const _ReportCard({required this.report, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    final isBudget = report.typeKey == 'budget';
    final typeColor = isBudget ? AppColors.info : AppColors.primaryRed;
    return AppAccentCard(
      accent: typeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppStatusBadge(
                label: isBudget ? 'Budget' : 'Accomplishment',
                color: typeColor,
              ),
              AppStatusBadge(
                label: _readable(report.status),
                color: _statusColor(report.status),
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppThumbnail(
                icon: isBudget
                    ? Icons.account_balance_wallet_outlined
                    : Icons.receipt_long_outlined,
                color: typeColor,
                size: 54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.period,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              AppMeta(
                icon: Icons.location_on_outlined,
                label: report.barangay,
                color: AppColors.primaryRed,
              ),
              AppMeta(
                icon: Icons.upload_file_outlined,
                label: report.method,
                color: AppColors.info,
              ),
              AppMeta(icon: Icons.schedule_rounded, label: report.submittedAt),
              if (report.amount.isNotEmpty)
                AppMeta(
                  icon: Icons.payments_outlined,
                  label: 'Total amount: ${report.amount}',
                  color: AppColors.success,
                ),
            ],
          ),
          if (report.fileUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenFile,
                borderRadius: BorderRadius.circular(AppSpace.controlRadius),
                child: Ink(
                  decoration: AppDecorations.inset(),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      const AppIconTile(
                        icon: Icons.picture_as_pdf_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.fileLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'Open submitted document',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: AppColors.info,
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
  final explicit = _firstValue(row, [
    'submitter_name',
    'submitted_by_name',
    'user_name',
    'author_name',
    'name',
  ], '');
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
      return AppColors.success;
    case 'rejected':
      return AppColors.primaryRed;
    case 'draft':
      return AppColors.warning;
    default:
      return AppColors.highlight;
  }
}
