import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

enum SubmissionKind { report, budget }

class OfficialSubmissionScreen extends StatefulWidget {
  final SubmissionKind kind;

  const OfficialSubmissionScreen({super.key, required this.kind});

  @override
  State<OfficialSubmissionScreen> createState() =>
      _OfficialSubmissionScreenState();
}

class _OfficialSubmissionScreenState extends State<OfficialSubmissionScreen> {
  static const MethodChannel _fileChannel = MethodChannel('sk360/file_viewer');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;

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
    if (MobileApiService.syncedData == null) _refresh();
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
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: _title,
                subtitle: _subtitle,
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: widget.kind == SubmissionKind.budget
                            ? 'Active Budget Slots'
                            : 'Active Report Slots',
                        count: slots.length,
                      ),
                      const SizedBox(height: 12),
                      if (slots.isEmpty)
                        const _EmptyText('No active slots right now.')
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: 'Recent Submissions',
                        count: submissions.length,
                      ),
                      const SizedBox(height: 12),
                      if (submissions.isEmpty)
                        const _EmptyText('No submissions yet.')
                      else
                        ...submissions.map((row) => _SubmissionTile(row: row)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _activeSlots() {
    final role = MobileApiService.currentUser?['role']?.toString();
    final roleLabel = role == 'sk_secretary' ? 'SK Secretary' : 'SK Chairman';
    final now = DateTime.now();
    final rows = _rows('submission_slots');

    return rows.where((slot) {
      final type = slot['submission_type']?.toString() ?? '';
      final status = slot['status']?.toString().toLowerCase() ?? 'open';
      final slotRole = slot['role']?.toString() ?? '';
      final start = DateTime.tryParse(slot['start_date']?.toString() ?? '');
      final end = DateTime.tryParse(slot['end_date']?.toString() ?? '');
      final inRole = slotRole == roleLabel || slotRole == 'Both';
      final inDate = (start == null || !now.isBefore(start)) &&
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
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _submit(Map<String, dynamic> slot) async {
    final remarksController = TextEditingController();
    String reportType = widget.kind == SubmissionKind.budget ? 'annual' : 'monthly';
    String quarter = 'Q1';
    PdfUpload? selectedFile;
    String selectedFileName = '';
    final now = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Submit ${slot['title'] ?? _title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reportType,
                  decoration: const InputDecoration(labelText: 'Period type'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                    DropdownMenuItem(value: 'annual', child: Text('Annual')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => reportType = value ?? reportType),
                ),
                if (reportType == 'quarterly')
                  DropdownButtonFormField<String>(
                    initialValue: quarter,
                    decoration: const InputDecoration(labelText: 'Quarter'),
                    items: const [
                      DropdownMenuItem(value: 'Q1', child: Text('Q1')),
                      DropdownMenuItem(value: 'Q2', child: Text('Q2')),
                      DropdownMenuItem(value: 'Q3', child: Text('Q3')),
                      DropdownMenuItem(value: 'Q4', child: Text('Q4')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => quarter = value ?? quarter),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    _showMessage('Opening PDF picker...');
                    final picked = await _pickPdf();
                    if (picked == null) return;
                    setDialogState(() {
                      selectedFile = picked;
                      selectedFileName = picked.name;
                    });
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    selectedFileName.isEmpty
                        ? 'Choose PDF file'
                        : selectedFileName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Remarks or summary',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRed),
              onPressed: selectedFile == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      remarksController.dispose();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await MobileApiService.storeOfficialSubmission(
        slotId: _int(slot['slot_id']),
        submissionType: _submissionType,
        pdfFile: selectedFile!,
        reportType: reportType,
        reportingYear: now.year,
        reportingMonth: reportType == 'monthly' ? now.month : null,
        reportingQuarter: reportType == 'quarterly' ? quarter : null,
        remarks: remarksController.text,
      );
      if (mounted) _showMessage('Submission synced.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      remarksController.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<PdfUpload?> _pickPdf() async {
    try {
      final result = await _fileChannel.invokeMapMethod<String, dynamic>('pickPdf');
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot['title']?.toString() ?? 'Submission slot',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            slot['description']?.toString() ?? 'No description provided.',
            style: const TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${slot['start_date'] ?? ''} to ${slot['end_date'] ?? ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
                child: Text(kind == SubmissionKind.budget ? 'Submit Budget' : 'Submit Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Map<String, dynamic> row;

  const _SubmissionTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final title = row['title']?.toString() ??
        row['report_title']?.toString() ??
        'Submission';
    final method = row['submission_method']?.toString() ?? 'submitted';
    final status = row['status']?.toString() ?? 'submitted';
    final date = row['submitted_at']?.toString() ??
        row['created_at']?.toString() ??
        'No date';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.softPink,
        child: Icon(Icons.description_outlined, color: AppColors.primaryRed),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$method | $date', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        status,
        style: const TextStyle(
          color: AppColors.primaryRed,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEFF3)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        Text('$count', style: const TextStyle(color: AppColors.primaryRed)),
      ],
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(text, style: const TextStyle(color: AppColors.lightText)),
      ),
    );
  }
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
