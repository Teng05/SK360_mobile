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
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _loadError;
  List<Map<String, dynamic>> _slots = [];
  Map<String, dynamic> _summary = {};
  int _statusFilter = 0;

  static const _statusFilters = ['All', 'Open', 'Closed'];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleSlots();
    final openSlots = _slots.where(_isOpen).toList();
    final budgetSlots = _slots
        .where((slot) => slot['submission_type'] == 'budget_report')
        .length;
    final closingSoon = openSlots.where((slot) {
      final days = _daysUntilEnd(slot);
      return days != null && days >= 0 && days <= 7;
    }).length;

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
          onRefresh: _loadSlots,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'Module Management',
                subtitle: 'Submission slots',
              ),
              if (_isLoading) const AppLoadingIndicator(),
              if (_loadError != null)
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to refresh',
                  message: 'Check your connection and try again.',
                  onAction: _loadSlots,
                ),
              const AppPageIntro(
                eyebrow: 'SK360 Submission Hub',
                title: 'Module Management',
                subtitle:
                    'Open submission windows for barangay accomplishment and '
                    'budget reports, then track what each council sends in.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: AppOverline(
                  'Submission metrics',
                  action: TextButton.icon(
                    onPressed: _isLoading ? null : _loadSlots,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.info,
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.sync_rounded, size: 17),
                    label: const Text('Refresh'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AppMetricGrid(
                  children: [
                    AppStatistic(
                      label: 'Total slots',
                      value: '${_summary['total_slots'] ?? 0}',
                      icon: Icons.inventory_2_outlined,
                      caption: _slots.isEmpty
                          ? 'No windows yet'
                          : '${_slots.length - budgetSlots} report · '
                                '$budgetSlots budget',
                    ),
                    AppStatistic(
                      label: 'Open',
                      value: '${_summary['open_slots'] ?? 0}',
                      icon: Icons.lock_open_rounded,
                      color: AppColors.success,
                      dot: true,
                      caption: 'Accepting submissions',
                    ),
                    AppStatistic(
                      label: 'Closing soon',
                      value: '$closingSoon',
                      icon: Icons.timer_outlined,
                      color: AppColors.warning,
                      dot: true,
                      caption: 'Ends within 7 days',
                      captionColor: closingSoon > 0 ? AppColors.warning : null,
                    ),
                    AppStatistic(
                      label: 'Closed',
                      value: '${_summary['closed_slots'] ?? 0}',
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.muted,
                      dot: true,
                      caption: 'No longer accepting',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Search slots, report types, or roles…',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              AppFilterPills(
                labels: _statusFilters,
                counts: [
                  _slots.length,
                  openSlots.length,
                  _slots.length - openSlots.length,
                ],
                selectedIndex: _statusFilter,
                onSelected: (index) => setState(() => _statusFilter = index),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: AppActionButton(
                  label: 'Create New Slot',
                  onPressed: _showCreateDialog,
                ),
              ),
              if (_slots.isEmpty && !_isLoading && _loadError == null)
                const AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Ready for your first submission window',
                  message:
                      'Use Create New Slot to set a report type, target role, and deadline.',
                )
              else if (visible.isEmpty && _slots.isNotEmpty)
                const AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No slots match',
                  message: 'Try another search term or status filter.',
                )
              else
                ...visible.map(
                  (slot) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

  /// Search and status filtering run on the slots already loaded above.
  List<Map<String, dynamic>> _visibleSlots() {
    final query = _searchController.text.trim().toLowerCase();
    return _slots.where((slot) {
      final open = _isOpen(slot);
      if (_statusFilter == 1 && !open) return false;
      if (_statusFilter == 2 && open) return false;
      if (query.isEmpty) return true;
      final text = [
        slot['title'],
        slot['description'],
        _typeLabel(slot),
        slot['role'],
        slot['status'],
      ].whereType<Object>().join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await MobileApiService.submissionSlots();
      final rows = response['slots'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _slots = rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _summary = Map<String, dynamic>.from(
          (response['summary'] as Map?) ?? {},
        );
      });
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _loadError = exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    String type = 'accomplishment_report';
    String role = 'Both';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => AppDialogForm(
        builder: (context, controllers) {
          final titleController = controllers[0];
          final descriptionController = controllers[1];
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              icon: const AppIconTile(icon: Icons.add_task_rounded),
              title: const Text('Create Submission Slot'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Field(
                        controller: titleController,
                        hint: 'Submission title',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: descriptionController,
                        hint: 'Description',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: type,
                        decoration: _decoration('Submission type', label: true),
                        items: const [
                          DropdownMenuItem(
                            value: 'accomplishment_report',
                            child: Text('Accomplishment Report'),
                          ),
                          DropdownMenuItem(
                            value: 'budget_report',
                            child: Text('Budget Report'),
                          ),
                        ],
                        onChanged: (value) => setDialogState(
                          () => type = value ?? 'accomplishment_report',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: role,
                        decoration: _decoration('Target role', label: true),
                        items: const [
                          DropdownMenuItem(
                            value: 'SK Chairman',
                            child: Text('SK Chairman'),
                          ),
                          DropdownMenuItem(
                            value: 'SK Secretary',
                            child: Text('SK Secretary'),
                          ),
                          DropdownMenuItem(value: 'Both', child: Text('Both')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => role = value ?? 'Both'),
                      ),
                      const SizedBox(height: 12),
                      AppAdaptiveRow(
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
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.lightText,
                  ),
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
                            _showMessage(
                              'End date cannot be before the start date.',
                            );
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
                  child: Text(isSubmitting ? 'Creating...' : 'Create'),
                ),
              ],
            ),
          );
        },
      ),
    );
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

    final title = slot['title']?.toString() ?? 'this submission slot';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const AppIconTile(icon: Icons.delete_outline_rounded),
        title: const Text('Delete submission slot?'),
        content: Text(
          'Are you sure you want to remove "$title"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.lightText),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final submitted = _submissions
        .where((row) => row['submitted'] == true)
        .length;

    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      body: SafeArea(
        child: Column(
          children: [
            PresidentHeader(
              leading: PresidentHeaderLeading.back,
              onLeadingTap: () => Navigator.maybePop(context),
              title: widget.title,
              subtitle: 'Barangay submissions',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadSubmissions,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    Text(
                      'Barangay Submissions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See which councils have sent in their file for this slot.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_submissions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ProgressCard(
                        submitted: submitted,
                        total: _submissions.length,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Search barangay...',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int submitted;
  final int total;

  const _ProgressCard({required this.submitted, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : submitted / total;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconTile(
                icon: Icons.task_alt_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$submitted',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      TextSpan(
                        text: ' of $total submitted',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.success,
              backgroundColor: AppColors.successSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              AppMeta(
                icon: Icons.check_circle_outline_rounded,
                label: '$submitted submitted',
                color: AppColors.success,
              ),
              AppMeta(
                icon: Icons.hourglass_empty_rounded,
                label: '${total - submitted} pending',
                color: AppColors.warning,
              ),
            ],
          ),
        ],
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
    final color = submitted ? AppColors.success : AppColors.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: AppDecorations.surface(),
      child: Row(
        children: [
          AppIconTile(
            icon: submitted
                ? Icons.check_circle_rounded
                : Icons.hourglass_empty_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 5),
                AppStatusBadge(
                  label: submitted ? 'Submitted' : 'No submission yet',
                  color: color,
                  dot: true,
                ),
              ],
            ),
          ),
          if (submitted && fileUrl != null && fileUrl.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MeetingWebViewScreen(
                    url: fileUrl,
                    title: '$name Submitted File',
                  ),
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.info),
              child: const Text('View File'),
            ),
        ],
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
    return AppEmptyState(
      icon: onRetry == null
          ? Icons.folder_open_outlined
          : Icons.cloud_off_outlined,
      title: onRetry == null
          ? 'No submissions to show'
          : 'Unable to load submissions',
      message: message,
      onAction: onRetry,
    );
  }
}

enum _SlotAction { view, toggle, delete }

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
    final description = slot['description']?.toString().trim() ?? '';
    final isOpen = _isOpen(slot);
    final isBudget = slot['submission_type'] == 'budget_report';
    final typeColor = isBudget ? AppColors.info : AppColors.primaryRed;
    final daysLeft = _daysUntilEnd(slot);
    final closingSoon =
        isOpen && daysLeft != null && daysLeft >= 0 && daysLeft <= 7;
    final accent = !isOpen
        ? AppColors.muted.withValues(alpha: .45)
        : closingSoon
        ? AppColors.warning
        : AppColors.primaryRed;

    return AppAccentCard(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(18, 10, 6, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppStatusBadge(
                      label: _typeLabel(slot),
                      color: isOpen ? typeColor : AppColors.muted,
                    ),
                    AppStatusBadge(
                      label: isOpen ? 'Open' : 'Closed',
                      color: isOpen ? AppColors.success : AppColors.muted,
                      dot: true,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_SlotAction>(
                tooltip: 'Slot actions',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.lightText,
                ),
                onSelected: (action) => switch (action) {
                  _SlotAction.view => onView(),
                  _SlotAction.toggle => onToggle(),
                  _SlotAction.delete => onDelete(),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _SlotAction.view,
                    child: _MenuRow(
                      icon: Icons.visibility_outlined,
                      label: 'View submissions',
                    ),
                  ),
                  PopupMenuItem(
                    value: _SlotAction.toggle,
                    child: _MenuRow(
                      icon: isOpen
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      label: isOpen ? 'Close slot' : 'Reopen slot',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _SlotAction.delete,
                    child: _MenuRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete slot',
                      color: AppColors.primaryRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppThumbnail(
                  icon: isBudget
                      ? Icons.account_balance_wallet_outlined
                      : Icons.assignment_outlined,
                  color: typeColor,
                  size: 66,
                  dimmed: !isOpen,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isOpen
                                  ? AppColors.darkGray
                                  : AppColors.lightText,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description.isEmpty
                            ? 'No description provided.'
                            : description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                AppMeta(
                  icon: Icons.date_range_outlined,
                  label: _rangeLabel(slot),
                  color: AppColors.info,
                ),
                AppMeta(
                  icon: Icons.groups_2_outlined,
                  label: _roleLabel(slot),
                  color: AppColors.primaryRed,
                ),
                AppMeta(
                  icon: closingSoon
                      ? Icons.timer_outlined
                      : Icons.schedule_rounded,
                  label: _timingLabel(slot, isOpen, daysLeft),
                  color: closingSoon ? AppColors.warning : null,
                  textColor: closingSoon ? AppColors.warning : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = AppColors.darkGray,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 12),
      Flexible(
        child: Text(label, style: TextStyle(color: color)),
      ),
    ],
  );
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
      borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      child: InputDecorator(
        decoration: _decoration(label, label: true).copyWith(
          suffixIcon: const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.primaryRed,
          ),
        ),
        child: Text(
          _dateText(date),
          style: const TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.w700,
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

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _decoration(hint),
    );
  }
}

InputDecoration _decoration(String text, {bool label = false}) {
  return InputDecoration(
    hintText: label ? null : text,
    labelText: label ? text : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}

bool _isOpen(Map<String, dynamic> slot) =>
    (slot['status']?.toString() ?? 'open') == 'open';

String _typeLabel(Map<String, dynamic> slot) =>
    slot['submission_type'] == 'budget_report'
    ? 'Budget report'
    : 'Accomplishment report';

String _roleLabel(Map<String, dynamic> slot) {
  final role = slot['role']?.toString().trim() ?? '';
  if (role.isEmpty) return 'All officials';
  if (role == 'Both') return 'Chairman & Secretary';
  return role;
}

int? _daysUntilEnd(Map<String, dynamic> slot) {
  final end = DateTime.tryParse(slot['end_date']?.toString() ?? '');
  if (end == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(end.year, end.month, end.day).difference(today).inDays;
}

String _rangeLabel(Map<String, dynamic> slot) {
  final start = DateTime.tryParse(slot['start_date']?.toString() ?? '');
  final end = DateTime.tryParse(slot['end_date']?.toString() ?? '');
  if (start == null || end == null) {
    return '${slot['start_date'] ?? ''} to ${slot['end_date'] ?? ''}';
  }
  final sameYear = start.year == end.year;
  return '${_shortDate(start, withYear: !sameYear)} – ${_shortDate(end)}';
}

String _timingLabel(Map<String, dynamic> slot, bool isOpen, int? daysLeft) {
  if (daysLeft == null) return isOpen ? 'Accepting' : 'Not accepting';
  if (daysLeft < 0) return 'Ended ${-daysLeft}d ago';
  if (!isOpen) return 'Closed early';
  final start = DateTime.tryParse(slot['start_date']?.toString() ?? '');
  if (start != null && start.isAfter(DateTime.now())) {
    return 'Opens ${_shortDate(start)}';
  }
  if (daysLeft == 0) return 'Due today';
  return daysLeft == 1 ? 'Due tomorrow' : 'Due in $daysLeft days';
}

String _shortDate(DateTime date, {bool withYear = true}) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final base = '${months[date.month - 1]} ${date.day}';
  return withYear ? '$base, ${date.year}' : base;
}

String _dateText(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}
