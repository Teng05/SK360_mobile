import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';
import '../shared/meeting_webview_screen.dart';

class ConsolidationScreen extends StatefulWidget {
  const ConsolidationScreen({super.key});

  @override
  State<ConsolidationScreen> createState() => _ConsolidationScreenState();
}

class _ConsolidationScreenState extends State<ConsolidationScreen> {
  static const int _pageSize = 10;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _loadError;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String _period = 'all';
  String _quarter = 'Q${((DateTime.now().month - 1) ~/ 3) + 1}';
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _submissions = [];
  List<int> _years = [DateTime.now().year];
  String _searchQuery = '';
  int _currentPage = 1;
  bool _initialLoad = true;
  String _reviewQuery = '';
  String _reviewFilter = 'all';
  int _reviewPage = 1;

  List<Map<String, dynamic>> get _reviewRows {
    final q = _reviewQuery.toLowerCase().trim();
    return _submissions.where((row) {
      final qualityStatus = '${row['quality_status'] ?? 'pending'}'
          .toLowerCase();
      final pendingReview =
          qualityStatus.isEmpty ||
          qualityStatus == 'pending' ||
          qualityStatus == 'pending_review' ||
          qualityStatus == 'for_review';
      return row['status'] == 'submitted' &&
          pendingReview &&
          (_reviewFilter == 'all' ||
              '${row['source_type'] ?? ''}'.contains(_reviewFilter)) &&
          (q.isEmpty || '${row['barangay'] ?? ''}'.toLowerCase().contains(q));
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSubmissions {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _submissions;
    return _submissions.where((row) {
      final barangay = row['barangay']?.toString().toLowerCase() ?? '';
      return barangay.contains(query);
    }).toList();
  }

  int get _pageCount => (_filteredSubmissions.length / _pageSize).ceil();

  List<Map<String, dynamic>> get _visibleSubmissions {
    final rows = _filteredSubmissions;
    if (rows.isEmpty) return [];
    final safePage = _currentPage.clamp(1, _pageCount);
    final start = (safePage - 1) * _pageSize;
    return rows.skip(start).take(_pageSize).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadConsolidation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          onRefresh: _loadConsolidation,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'Consolidation',
                subtitle: 'Barangay submissions',
              ),
              if (_isLoading) const AppLoadingIndicator(),
              if (_loadError != null)
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to refresh',
                  message: 'Check your connection and try again.',
                  onAction: _loadConsolidation,
                ),
              const AppPageIntro(
                eyebrow: 'Federation overview',
                title: 'Consolidation',
                subtitle:
                    'Track which barangays have submitted for each reporting period.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: _Filters(
                  year: _year,
                  years: _years,
                  period: _period,
                  month: _month,
                  quarter: _quarter,
                  onChanged: (year, period, month, quarter) {
                    setState(() {
                      _year = year;
                      _period = period;
                      _month = month;
                      _quarter = quarter;
                      _currentPage = 1;
                    });
                    _loadConsolidation();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppMetricGrid(
                  columns: 3,
                  children: [
                    _Stat(
                      label: 'Total',
                      value: '${_stats['total_barangays'] ?? 0}',
                      icon: Icons.location_city_outlined,
                    ),
                    _Stat(
                      label: 'Submitted',
                      value: '${_stats['submitted'] ?? 0}',
                      icon: Icons.task_alt_rounded,
                      color: AppColors.success,
                    ),
                    _Stat(
                      label: 'Pending',
                      value: '${_stats['pending'] ?? 0}',
                      icon: Icons.hourglass_empty_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search barangay...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _currentPage = 1;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (value) => setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: AppSectionHeading(
                  icon: Icons.folder_copy_outlined,
                  title: 'Barangay submissions',
                  action: AppStatusBadge(
                    label: '${_filteredSubmissions.length}',
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
              if (_filteredSubmissions.isEmpty &&
                  !_isLoading &&
                  _loadError == null)
                AppEmptyState(
                  icon: Icons.folder_copy_outlined,
                  title: _searchQuery.isEmpty
                      ? 'No records for this period'
                      : 'No barangay found',
                  message: _searchQuery.isEmpty
                      ? 'Choose another reporting period or pull down to refresh.'
                      : 'Try a different barangay name.',
                )
              else
                ..._visibleSubmissions.map(
                  (row) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _BarangaySubmissionCard(row: row),
                  ),
                ),
              if (_pageCount > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _PaginationControls(
                    currentPage: _currentPage,
                    pageCount: _pageCount,
                    totalItems: _filteredSubmissions.length,
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: AppSectionHeading(
                  icon: Icons.verified_outlined,
                  title: 'Quality Documentation Review',
                  action: AppStatusBadge(
                    label:
                        '${_filteredSubmissions.where((r) => r['status'] == 'submitted').length}',
                    color: AppColors.warning,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search barangay...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() {
                    _reviewQuery = v;
                    _reviewPage = 1;
                  }),
                ),
              ),
              AppFilterPills(
                labels: const [
                  'All',
                  'Report submissions',
                  'Budget submissions',
                ],
                selectedIndex: [
                  'all',
                  'accomplishment_report',
                  'budget_report',
                ].indexOf(_reviewFilter),
                onSelected: (i) => setState(() {
                  _reviewFilter = [
                    'all',
                    'accomplishment_report',
                    'budget_report',
                  ][i];
                  _reviewPage = 1;
                }),
              ),
              ..._reviewRows
                  .skip((_reviewPage - 1) * 5)
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: _QualityReviewCard(
                        row: row,
                        onSaved: _loadConsolidation,
                      ),
                    ),
                  ),
              if ((_reviewRows.length / 5).ceil() > 1)
                _PaginationControls(
                  currentPage: _reviewPage,
                  pageCount: (_reviewRows.length / 5).ceil(),
                  totalItems: _reviewRows.length,
                  onPageChanged: (p) => setState(() => _reviewPage = p),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadConsolidation() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await MobileApiService.consolidation(
        // Let the API choose the active-term year on the first load, matching
        // the web consolidation default instead of using the phone's clock.
        year: _initialLoad ? null : _year,
        period: _period,
        month: _month,
        quarter: _quarter,
      );
      final submissions = response['submissions'] as List<dynamic>? ?? [];
      final years = response['years'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from((response['stats'] as Map?) ?? {});
        _submissions = submissions
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _currentPage = 1;
        _years =
            years
                .map((year) => int.tryParse('$year') ?? DateTime.now().year)
                .toSet()
                .toList()
              ..sort((a, b) => b.compareTo(a));
        _year = int.tryParse('${response['filters']?['year']}') ?? _year;
        _initialLoad = false;
      });
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _loadError = exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    handleRoleNavSelection(context, item);
  }
}

class _Filters extends StatelessWidget {
  final int year;
  final List<int> years;
  final String period;
  final int month;
  final String quarter;
  final void Function(int year, String period, int month, String quarter)
  onChanged;

  const _Filters({
    required this.year,
    required this.years,
    required this.period,
    required this.month,
    required this.quarter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.surface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppOverline('Reporting period'),
          const SizedBox(height: 12),
          AppAdaptiveRow(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: year,
                  decoration: _filterDecoration('Year'),
                  items: years
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      onChanged(value ?? year, period, month, quarter),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: period,
                  decoration: _filterDecoration('Period'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                      value: 'quarterly',
                      child: Text('Quarterly'),
                    ),
                    DropdownMenuItem(value: 'annual', child: Text('Annual')),
                  ],
                  onChanged: (value) =>
                      onChanged(year, value ?? period, month, quarter),
                ),
              ),
            ],
          ),
          if (period == 'monthly' || period == 'quarterly') ...[
            const SizedBox(height: 12),
            AppAdaptiveRow(
              children: [
                if (period == 'monthly')
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: month,
                      decoration: _filterDecoration('Month'),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}'),
                        ),
                      ),
                      onChanged: (value) =>
                          onChanged(year, period, value ?? month, quarter),
                    ),
                  ),
                if (period == 'quarterly')
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: quarter,
                      decoration: _filterDecoration('Quarter'),
                      items: const [
                        DropdownMenuItem(value: 'Q1', child: Text('Q1')),
                        DropdownMenuItem(value: 'Q2', child: Text('Q2')),
                        DropdownMenuItem(value: 'Q3', child: Text('Q3')),
                        DropdownMenuItem(value: 'Q4', child: Text('Q4')),
                      ],
                      onChanged: (value) =>
                          onChanged(year, period, month, value ?? quarter),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _filterDecoration(String label) {
  return InputDecoration(
    labelText: label,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primaryRed,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatistic(
      label: label,
      value: value,
      icon: icon,
      color: color,
      dot: color != AppColors.primaryRed,
    );
  }
}

class _BarangaySubmissionCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _BarangaySubmissionCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final submitted = row['status'] == 'submitted';
    final name = row['barangay']?.toString() ?? 'Barangay';
    final color = submitted ? AppColors.success : AppColors.warning;

    return AppAccentCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(
                icon: Icons.location_city_outlined,
                color: AppColors.primaryRed,
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppStatusBadge(
            label: submitted ? 'Submitted' : 'Pending',
            color: color,
            dot: true,
          ),
          if (submitted) ...[
            const SizedBox(height: 8),
            AppStatusBadge(
              label: _qualityLabel(row),
              color: _qualityColor(row),
              dot: true,
            ),
          ],
          const SizedBox(height: 12),
          _Line(
            label: 'Monthly',
            value: row['monthly']?.toString() ?? 'Pending',
          ),
          _Line(
            label: 'Quarterly',
            value: row['quarterly']?.toString() ?? 'Pending',
          ),
          _Line(label: 'Annual', value: row['annual']?.toString() ?? 'Pending'),
          const SizedBox(height: 10),
          AppMeta(
            icon: Icons.schedule_rounded,
            label: 'Last: ${row['last_submission']}',
          ),
        ],
      ),
    );
  }

  String _qualityLabel(Map<String, dynamic> row) {
    switch ('${row['quality_status'] ?? 'pending'}'.toLowerCase()) {
      case 'approved':
        return 'Quality Approved';
      case 'needs_revision':
        return 'Needs Revision';
      default:
        return 'For Quality Review';
    }
  }

  Color _qualityColor(Map<String, dynamic> row) {
    switch ('${row['quality_status'] ?? 'pending'}'.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'needs_revision':
        return AppColors.primaryRed;
      default:
        return AppColors.warning;
    }
  }
}

class _QualityReviewCard extends StatefulWidget {
  final Map<String, dynamic> row;
  final Future<void> Function() onSaved;

  const _QualityReviewCard({required this.row, required this.onSaved});

  @override
  State<_QualityReviewCard> createState() => _QualityReviewCardState();
}

class _QualityReviewCardState extends State<_QualityReviewCard> {
  bool complete = false, document = false, period = false, saving = false;
  final remarks = TextEditingController();

  @override
  void dispose() {
    remarks.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(String status) async {
    final id = int.tryParse(
      '${widget.row['source_id'] ?? widget.row['report_id'] ?? widget.row['budget_report_id'] ?? ''}',
    );
    if (id == null) {
      _message('Unable to identify this submission.');
      return;
    }
    if (status == 'approved' && (!complete || !document || !period)) {
      _message(
        'Check Complete Contents, Correct Document, and Correct Period first.',
      );
      return;
    }
    if (status == 'needs_revision' && remarks.text.trim().isEmpty) {
      _message('Add review remarks before requesting a revision.');
      return;
    }
    setState(() => saving = true);
    try {
      await MobileApiService.submitQualityReview(
        sourceType: '${widget.row['source_type'] ?? 'accomplishment_report'}',
        sourceId: id,
        status: status,
        completeContents: complete,
        correctDocument: document,
        correctPeriod: period,
        remarks: remarks.text.trim(),
      );
      _message(
        status == 'approved'
            ? 'Quality review approved.'
            : 'Submission returned for revision.',
      );
      await widget.onSaved();
    } on MobileApiException catch (exception) {
      _message(exception.message);
    } catch (_) {
      _message('Unable to save the quality review. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final url = [row['document_url'], row['uploaded_file_url'], row['mobile_view_url']]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconTile(
                icon: Icons.description_outlined,
                color: AppColors.primaryRed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${row['barangay'] ?? 'Barangay'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const AppStatusBadge(
                      label: 'Pending Review',
                      color: AppColors.warning,
                      dot: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${row['source_title'] ?? row['source_label'] ?? 'Submission'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${row['source_label'] ?? 'Submission'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${row['reporting_period'] ?? row['period'] ?? 'Annual'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Submitted: ${row['last_submission'] ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: url.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MeetingWebViewScreen(
                        url: url,
                        title: 'Submitted Document',
                      ),
                    ),
                  ),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('View Document'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Complete Contents'),
                selected: complete,
                onSelected: (value) => setState(() => complete = value),
              ),
              FilterChip(
                label: const Text('Correct Document'),
                selected: document,
                onSelected: (value) => setState(() => document = value),
              ),
              FilterChip(
                label: const Text('Correct Period'),
                selected: period,
                onSelected: (value) => setState(() => period = value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: remarks,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Review Remarks',
              hintText: 'Add remarks, especially when revision is needed...',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: saving ? null : () => _save('needs_revision'),
                child: const Text('Needs Revision'),
              ),
              FilledButton(
                onPressed: saving ? null : () => _save('approved'),
                child: const Text('Approve Quality'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final int totalItems;
  final ValueChanged<int> onPageChanged;

  const _PaginationControls({
    required this.currentPage,
    required this.pageCount,
    required this.totalItems,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final firstItem = ((currentPage - 1) * 10) + 1;
    final lastItem = (currentPage * 10).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppDecorations.surface(),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Page $currentPage of $pageCount',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Showing $firstItem–$lastItem of $totalItems',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: currentPage < pageCount
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final done = value.toLowerCase().contains('submitted');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppDecorations.inset(radius: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.lightText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: done ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
