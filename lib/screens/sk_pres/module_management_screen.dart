import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';
import '../shared/meeting_webview_screen.dart';

class ModuleManagementScreen extends StatefulWidget {
  const ModuleManagementScreen({super.key});

  @override
  State<ModuleManagementScreen> createState() => _ModuleManagementScreenState();
}

class _ModuleManagementScreenState extends State<ModuleManagementScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  List<Map<String, dynamic>> _slots = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadSlots();
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Slot'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSlots,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'Module Management',
                subtitle: 'Submission slots',
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: _SummaryCard(label: 'Total', value: '${_summary['total_slots'] ?? 0}')),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryCard(label: 'Open', value: '${_summary['open_slots'] ?? 0}')),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryCard(label: 'Closed', value: '${_summary['closed_slots'] ?? 0}')),
                  ],
                ),
              ),
              if (_slots.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No submission slots yet.', style: TextStyle(color: AppColors.lightText)),
                  ),
                )
              else
                ..._slots.map(
                  (slot) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _SlotCard(
                      slot: slot,
                      onDelete: () => _deleteSlot(slot),
                      onToggle: () => _toggleSlot(slot),
                      onView: () => _viewSubmissions(slot),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);
    try {
      final response = await MobileApiService.submissionSlots();
      final rows = response['slots'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _slots = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _summary = Map<String, dynamic>.from((response['summary'] as Map?) ?? {});
      });
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    String type = 'accomplishment_report';
    String role = 'Both';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Submission Slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(controller: titleController, hint: 'Submission title'),
                const SizedBox(height: 10),
                _Field(controller: descriptionController, hint: 'Description', maxLines: 2),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: _decoration('Submission type'),
                  items: const [
                    DropdownMenuItem(value: 'accomplishment_report', child: Text('Accomplishment Report')),
                    DropdownMenuItem(value: 'budget_report', child: Text('Budget Report')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? 'accomplishment_report'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: _decoration('Target role'),
                  items: const [
                    DropdownMenuItem(value: 'SK Chairman', child: Text('SK Chairman')),
                    DropdownMenuItem(value: 'SK Secretary', child: Text('SK Secretary')),
                    DropdownMenuItem(value: 'Both', child: Text('Both')),
                  ],
                  onChanged: (value) => setDialogState(() => role = value ?? 'Both'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Start date',
                        date: startDate,
                        onTap: () async {
                          final picked = await _pickDate(
                            initialDate: startDate,
                          );
                          if (picked == null) return;

                          setDialogState(() {
                            startDate = picked;
                            if (endDate.isBefore(startDate)) {
                              endDate = startDate;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DatePickerField(
                        label: 'End date',
                        date: endDate,
                        onTap: () async {
                          final picked = await _pickDate(
                            initialDate: endDate.isBefore(startDate)
                                ? startDate
                                : endDate,
                            firstDate: startDate,
                          );
                          if (picked == null) return;

                          setDialogState(() => endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        _showMessage('Enter a submission title.');
                        return;
                      }

                      if (endDate.isBefore(startDate)) {
                        _showMessage('End date cannot be before the start date.');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final created = await _createSlot(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        type: type,
                        role: role,
                        start: startDate,
                        end: endDate,
                      );
                      if (created) {
                        if (context.mounted) Navigator.pop(context);
                      } else {
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
              child: Text(isSubmitting ? 'Creating...' : 'Create'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    DateTime? firstDate,
  }) {
    final earliest = firstDate ?? DateTime(DateTime.now().year - 1);
    final safeInitial = initialDate.isBefore(earliest) ? earliest : initialDate;

    return showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: earliest,
      lastDate: DateTime(DateTime.now().year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryRed,
            onPrimary: Colors.white,
            onSurface: AppColors.darkGray,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  Future<bool> _createSlot({
    required String title,
    required String description,
    required String type,
    required String role,
    required DateTime start,
    required DateTime end,
  }) async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.createSubmissionSlot(
        submissionType: type,
        title: title,
        role: role,
        startDate: start,
        endDate: end,
        description: description,
      );
      await _loadSlots();
      if (mounted) _showMessage('Submission slot created.');
      return true;
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSlot(Map<String, dynamic> slot) async {
    final slotId = int.tryParse('${slot['slot_id']}');
    if (slotId == null) return;

    setState(() => _isLoading = true);
    try {
      await MobileApiService.deleteSubmissionSlot(slotId);
      await _loadSlots();
      if (mounted) _showMessage('Submission slot deleted.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSlot(Map<String, dynamic> slot) async {
    final slotId = int.tryParse('${slot['slot_id']}');
    if (slotId == null) return;

    setState(() => _isLoading = true);
    try {
      await MobileApiService.toggleSubmissionSlot(slotId);
      await _loadSlots();
      if (mounted) _showMessage('Submission slot status updated.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _viewSubmissions(Map<String, dynamic> slot) async {
    final slotId = int.tryParse('${slot['slot_id']}');
    if (slotId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmissionSlotSubmissionsPage(
          slotId: slotId,
          title: slot['title']?.toString() ?? 'Submissions',
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }

  void _handleNavSelection(PresidentNavItem item) {
    handleRoleNavSelection(context, item);
  }
}

class SubmissionSlotSubmissionsPage extends StatefulWidget {
  final int slotId;
  final String title;

  const SubmissionSlotSubmissionsPage({
    super.key,
    required this.slotId,
    required this.title,
  });

  @override
  State<SubmissionSlotSubmissionsPage> createState() =>
      _SubmissionSlotSubmissionsPageState();
}

class _SubmissionSlotSubmissionsPageState
    extends State<SubmissionSlotSubmissionsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await MobileApiService.submissionSlotSubmissions(
        widget.slotId,
      );
      if (!mounted) return;
      setState(() {
        _submissions = (response['submissions'] as List<dynamic>? ?? [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _submissions.where((row) {
      final name = row['barangay_name']?.toString().toLowerCase() ?? '';
      return query.isEmpty || name.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubmissions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Barangay Submissions',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search barangay...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _SubmissionMessage(
                message: _error!,
                onRetry: _loadSubmissions,
              )
            else if (filtered.isEmpty)
              const _SubmissionMessage(message: 'No barangays found.')
            else
              ...filtered.map((row) => _SubmissionRow(row: row)),
          ],
        ),
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _SubmissionRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final submitted = row['submitted'] == true;
    final fileUrl = row['file_url']?.toString();
    final name = row['barangay_name']?.toString() ?? 'Barangay';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(submitted ? 'Submitted' : 'No submission yet'),
        leading: Icon(
          submitted ? Icons.check_circle : Icons.hourglass_empty,
          color: submitted ? Colors.green : AppColors.lightText,
        ),
        trailing: submitted && fileUrl != null && fileUrl.isNotEmpty
            ? TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingWebViewScreen(
                      url: fileUrl,
                      title: '$name Submitted File',
                    ),
                  ),
                ),
                child: const Text('View File'),
              )
            : null,
      ),
    );
  }
}

class _SubmissionMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _SubmissionMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
          Text(label, style: const TextStyle(color: AppColors.lightText)),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback onView;

  const _SlotCard({
    required this.slot,
    required this.onDelete,
    required this.onToggle,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final title = slot['title']?.toString() ?? 'Submission Slot';
    final status = slot['status']?.toString() ?? 'open';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          Row(
            children: [
          CircleAvatar(
            backgroundColor: status == 'open' ? const Color(0xFFE8F5E9) : AppColors.softPink,
            child: Icon(
              status == 'open' ? Icons.lock_open : Icons.lock_outline,
              color: status == 'open' ? Colors.green : AppColors.primaryRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGray)),
                const SizedBox(height: 4),
                Text(
                  '${slot['submission_type']} - ${slot['role']}',
                  style: const TextStyle(color: AppColors.lightText, fontSize: 12),
                ),
                Text(
                  '${slot['start_date']} to ${slot['end_date']}',
                  style: const TextStyle(color: AppColors.lightText, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.primaryRed),
          ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.people_alt_outlined, size: 16),
                  label: const Text('View Barangays'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(status == 'open' ? Icons.lock_outline : Icons.lock_open, size: 16),
                  label: Text(status == 'open' ? 'Close' : 'Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'open' ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _decoration(label).copyWith(
          suffixIcon: const Icon(
            Icons.calendar_month,
            color: AppColors.primaryRed,
          ),
        ),
        child: Text(
          _dateText(date),
          style: const TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _Field({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _decoration(hint),
    );
  }
}

InputDecoration _decoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.softPink,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

String _dateText(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}
