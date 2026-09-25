import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../utils/submitted_file_opener.dart';
import '../../widgets/president_components.dart';

enum SubmissionKind { report, budget }

class OfficialSubmissionScreen extends StatefulWidget {
  final SubmissionKind kind;

  const OfficialSubmissionScreen({super.key, required this.kind});

  @override
  State<OfficialSubmissionScreen> createState() =>
      _OfficialSubmissionScreenState();
}

class _OfficialSubmissionScreenState extends State<OfficialSubmissionScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _fileChannel = MethodChannel('sk360/file_viewer');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  String? _loadError;

  String get _submissionType => widget.kind == SubmissionKind.budget
      ? 'budget_report'
      : 'accomplishment_report';
  String get _title =>
      widget.kind == SubmissionKind.budget ? 'Budget' : 'Reports';
  String get _subtitle => widget.kind == SubmissionKind.budget
      ? 'Budget submissions'
      : 'Accomplishment reports';

  Map<String, dynamic> get _data => MobileApiService.syncedData ?? {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slots = _activeSlots();
    final submissions = _submissions();

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
                title: _title,
                subtitle: _subtitle,
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
              AppPageIntro(
                eyebrow: widget.kind == SubmissionKind.budget
                    ? 'Budget office'
                    : 'Council reports',
                title: _title,
                subtitle: widget.kind == SubmissionKind.budget
                    ? 'Upload budget documents to open federation windows.'
                    : 'Upload accomplishment reports to open federation windows.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.inventory_2_outlined,
                      title: widget.kind == SubmissionKind.budget
                          ? 'Active Budget Slots'
                          : 'Active Report Slots',
                      count: slots.length,
                    ),
                    const SizedBox(height: 12),
                    if (slots.isEmpty)
                      const _Panel(
                        child: _EmptyText('No active slots right now.'),
                      )
                    else
                      ...slots.map(
                        (slot) => _SlotTile(
                          slot: slot,
                          kind: widget.kind,
                          onSubmit: () => _submit(slot),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.history_rounded,
                      title: 'Recent Submissions',
                      count: submissions.length,
                    ),
                    const SizedBox(height: 12),
                    if (submissions.isEmpty)
                      const _Panel(child: _EmptyText('No submissions yet.'))
                    else
                      ...submissions.map(
                        (row) => _SubmissionTile(
                          row: row,
                          onTap: () => _openFinancialRecord(row),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _activeSlots() {
    final role = MobileApiService.currentUser?['role']
        ?.toString()
        .trim()
        .toLowerCase();
    final roleLabel = role == 'sk_secretary' ? 'sk secretary' : 'sk chairman';
    final now = DateTime.now();
    final rows = _rows('submission_slots');

    return rows.where((slot) {
      final type = slot['submission_type']?.toString().trim().toLowerCase();
      final status = slot['status']?.toString().trim().toLowerCase();
      final slotRole = slot['role']?.toString().trim().toLowerCase();
      final start = DateTime.tryParse(slot['start_date']?.toString() ?? '');
      final end = DateTime.tryParse(slot['end_date']?.toString() ?? '');
      final inRole = slotRole == roleLabel || slotRole == 'both';
      final inDate =
          (start == null || !now.isBefore(start)) &&
          (end == null || !now.isAfter(end.add(const Duration(days: 1))));
      return type == _submissionType && status == 'open' && inRole && inDate;
    }).toList();
  }

  List<Map<String, dynamic>> _submissions() {
    final key = widget.kind == SubmissionKind.budget
        ? 'budget_reports'
        : 'accomplishment_reports';
    final rows = _rows(key);
    rows.sort(
      (a, b) => (b['submitted_at'] ?? b['created_at'] ?? '')
          .toString()
          .compareTo((a['submitted_at'] ?? a['created_at'] ?? '').toString()),
    );
    return rows;
  }

  List<Map<String, dynamic>> _rows(String key) {
    final rows = _data[key] as List<dynamic>? ?? [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void _openFinancialRecord(Map<String, dynamic> row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FinancialRecordDetailsPage(record: row),
      ),
    );
  }

  Future<void> _submit(Map<String, dynamic> slot) async {
    final draft = await Navigator.of(context).push<_SubmissionDraft>(
      MaterialPageRoute(
        builder: (_) => _SubmissionFormPage(
          title: slot['title']?.toString() ?? _title,
          kind: widget.kind,
          pickPdf: _pickPdf,
          initialReportType: slot['budget_period_type']?.toString(),
        ),
      ),
    );
    if (draft == null || !mounted) return;

    final now = DateTime.now();
    final isBudget = widget.kind == SubmissionKind.budget;

    setState(() => _isLoading = true);
    try {
      await MobileApiService.storeOfficialSubmission(
        slotId: _int(slot['slot_id']),
        submissionType: _submissionType,
        pdfFile: draft.file,
        reportType: isBudget ? draft.reportType : null,
        reportingYear: isBudget ? now.year : null,
        reportingMonth: isBudget && draft.reportType == 'monthly'
            ? now.month
            : null,
        reportingQuarter: isBudget && draft.reportType == 'quarterly'
            ? draft.quarter
            : null,
        remarks: draft.remarks,
      );
      if (mounted) _showMessage('Submission synced.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<PdfUpload?> _pickPdf() async {
    try {
      final result = await _fileChannel.invokeMapMethod<String, dynamic>(
        'pickPdf',
      );
      if (result == null) return null;

      final name = result['name']?.toString() ?? 'selected.pdf';
      final encoded = result['base64']?.toString() ?? '';
      if (encoded.isEmpty) {
        _showMessage('Unable to read selected PDF.');
        return null;
      }

      return PdfUpload(name: name, bytes: base64Decode(encoded));
    } on MissingPluginException {
      _showMessage('Rebuild the app first so the PDF picker is installed.');
      return null;
    } on PlatformException catch (exception) {
      _showMessage(exception.message ?? 'Unable to choose PDF file.');
      return null;
    } catch (exception) {
      _showMessage('Unable to choose PDF file: $exception');
      return null;
    }
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
}

class _SubmissionDraft {
  final PdfUpload file;
  final String reportType;
  final String quarter;
  final String remarks;

  const _SubmissionDraft({
    required this.file,
    required this.reportType,
    required this.quarter,
    required this.remarks,
  });
}

class _SubmissionFormPage extends StatefulWidget {
  final String title;
  final SubmissionKind kind;
  final Future<PdfUpload?> Function() pickPdf;
  final String? initialReportType;

  const _SubmissionFormPage({
    required this.title,
    required this.kind,
    required this.pickPdf,
    this.initialReportType,
  });

  @override
  State<_SubmissionFormPage> createState() => _SubmissionFormPageState();
}

class _SubmissionFormPageState extends State<_SubmissionFormPage> {
  final _remarksController = TextEditingController();
  late String _reportType;
  String _quarter = 'Q1';
  PdfUpload? _file;
  bool _isPickingFile = false;

  @override
  void initState() {
    super.initState();
    _reportType = widget.kind == SubmissionKind.budget
        ? (widget.initialReportType?.isNotEmpty == true
              ? widget.initialReportType!
              : 'annual')
        : 'monthly';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Submit ${widget.title}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.darkGray,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppSectionHeading(
            title: 'Submission details',
            subtitle: widget.kind == SubmissionKind.budget
                ? 'Select a reporting period, attach your PDF, and add any remarks.'
                : 'Attach your completed report PDF and add any remarks.',
          ),
          const SizedBox(height: 24),
          if (widget.kind == SubmissionKind.budget)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  const ['monthly', 'quarterly', 'annual'].contains(_reportType)
                  ? _reportType
                  : 'annual',
              decoration: const InputDecoration(labelText: 'Period type'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                DropdownMenuItem(value: 'annual', child: Text('Annual')),
              ],
              onChanged: widget.initialReportType?.isNotEmpty == true
                  ? null
                  : (value) {
                      if (value != null) setState(() => _reportType = value);
                    },
            ),
          if (widget.kind == SubmissionKind.budget &&
              _reportType == 'quarterly') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _quarter,
              decoration: const InputDecoration(labelText: 'Quarter'),
              items: const [
                DropdownMenuItem(value: 'Q1', child: Text('Q1')),
                DropdownMenuItem(value: 'Q2', child: Text('Q2')),
                DropdownMenuItem(value: 'Q3', child: Text('Q3')),
                DropdownMenuItem(value: 'Q4', child: Text('Q4')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _quarter = value);
              },
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isPickingFile ? null : _chooseFile,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              _isPickingFile
                  ? 'Opening files…'
                  : _file?.name ?? 'Choose PDF file',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarksController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Remarks or summary',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          AppAdaptiveRow(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _file == null ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                  ),
                  child: const Text('Submit PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseFile() async {
    setState(() => _isPickingFile = true);
    final file = await widget.pickPdf();
    if (!mounted) return;
    setState(() {
      _file = file ?? _file;
      _isPickingFile = false;
    });
  }

  void _submit() {
    final file = _file;
    if (file == null) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _SubmissionDraft(
        file: file,
        reportType: _reportType,
        quarter: _quarter,
        remarks: _remarksController.text,
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final Map<String, dynamic> slot;
  final SubmissionKind kind;
  final VoidCallback onSubmit;

  const _SlotTile({
    required this.slot,
    required this.kind,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isBudget = kind == SubmissionKind.budget;
    final typeColor = isBudget ? AppColors.info : AppColors.primaryRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppAccentCard(
        accent: AppColors.primaryRed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppStatusBadge(
                  label: isBudget ? 'Budget report' : 'Accomplishment report',
                  color: typeColor,
                ),
                const AppStatusBadge(
                  label: 'Open',
                  color: AppColors.success,
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
                      : Icons.assignment_outlined,
                  color: typeColor,
                  size: 54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot['title']?.toString() ?? 'Submission slot',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        slot['description']?.toString() ??
                            'No description provided.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppMeta(
              icon: Icons.date_range_outlined,
              label: '${slot['start_date'] ?? ''} to ${slot['end_date'] ?? ''}',
              color: AppColors.info,
            ),
            if (isBudget &&
                (slot['budget_category']?.toString().isNotEmpty == true ||
                    slot['budget_period_type']?.toString().isNotEmpty ==
                        true)) ...[
              const SizedBox(height: 6),
              AppMeta(
                icon: Icons.category_outlined,
                label:
                    [
                          slot['budget_category']?.toString(),
                          slot['budget_period_type']?.toString(),
                        ]
                        .where((value) => value != null && value.isNotEmpty)
                        .join(' · '),
                color: AppColors.info,
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSubmit,
                style: AppCardButtonStyle.primary(),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(isBudget ? 'Submit Budget' : 'Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback? onTap;

  const _SubmissionTile({required this.row, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title =
        row['title']?.toString() ??
        row['report_title']?.toString() ??
        'Submission';
    final status =
        row['quality_status']?.toString() ??
        row['status']?.toString() ??
        'submitted';
    final date =
        row['submitted_at']?.toString() ??
        row['created_at']?.toString() ??
        'No date';
    final color = status == 'needs_revision' || status == 'rejected'
        ? AppColors.error
        : status == 'pending' || status == 'submitted'
        ? AppColors.warning
        : AppColors.success;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpace.radius),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.surface(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconTile(
              icon: Icons.description_outlined,
              color: color,
              size: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  AppMeta(icon: Icons.schedule_rounded, label: date),
                  const SizedBox(height: 8),
                  AppStatusBadge(
                    label: status.replaceAll('_', ' '),
                    color: color,
                    dot: true,
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.lightText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinancialRecordDetailsPage extends StatelessWidget {
  final Map<String, dynamic> record;

  const _FinancialRecordDetailsPage({required this.record});

  String _value(List<String> keys) {
    for (final key in keys) {
      final value = record[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String get _fileUrl {
    final url = _value(['uploaded_file_url', 'generated_pdf_url']);
    if (url.isNotEmpty) return url;
    final path = _value(['uploaded_file_path', 'generated_pdf_path']);
    return path.isEmpty ? '' : MobileApiService.webUrl(path);
  }

  Future<void> _openFile(BuildContext context) async {
    final result = await SubmittedFileOpener.open(_fileUrl);
    if (!result.opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Unable to open file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _value(['title', 'report_title']);
    final status = _value(['quality_status', 'status']);
    final qualityRemarks = _value(['quality_remarks']);
    final year = _value(['fiscal_year', 'reporting_year']);
    final period = _value(['budget_period_type', 'report_type']);
    final month = _value(['fiscal_month', 'reporting_month']);
    final quarter = _value(['fiscal_quarter', 'reporting_quarter']);
    final fileName = _value(['uploaded_file_name']);
    final submittedAt = _value(['submitted_at', 'created_at']);

    return Scaffold(
      appBar: AppBar(title: const Text('Submitted Report')),
      backgroundColor: AppColors.lightGrayBg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionHeading(
            title: title.isEmpty ? 'Financial document' : title,
            subtitle: 'Submitted document',
          ),
          const SizedBox(height: 16),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecordDetail(label: 'Status', value: status),
                _RecordDetail(label: 'Submitted', value: submittedAt),
                _RecordDetail(label: 'Fiscal year', value: year),
                _RecordDetail(label: 'Period type', value: period),
                _RecordDetail(label: 'Month', value: month),
                _RecordDetail(label: 'Quarter', value: quarter),
                _RecordDetail(
                  label: 'Document type',
                  value: _value(['document_type']),
                ),
                _RecordDetail(
                  label: 'Submission method',
                  value: _value(['submission_method']),
                ),
                _RecordDetail(
                  label: 'Total amount',
                  value: _value(['total_amount']),
                ),
                _RecordDetail(
                  label: 'Barangay',
                  value: _value(['barangay_name', 'barangay_id']),
                ),
                _RecordDetail(label: 'File', value: fileName),
                _RecordDetail(label: 'Remarks', value: _value(['remarks'])),
                _RecordDetail(label: 'Review remarks', value: qualityRemarks),
                _RecordDetail(
                  label: 'Record ID',
                  value: _value(['budget_report_id']),
                ),
              ],
            ),
          ),
          if (_fileUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openFile(context),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Open submitted document'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordDetail extends StatelessWidget {
  final String label;
  final String value;

  const _RecordDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return AppSurface(child: child);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionHeading(
      icon: icon,
      title: title,
      action: AppStatusBadge(label: '$count', color: AppColors.primaryRed),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.description_outlined,
      title: text,
      message: text.contains('active')
          ? 'New submission windows will appear here when opened by the federation.'
          : 'Choose an open submission window above to upload your PDF.',
    );
  }
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
