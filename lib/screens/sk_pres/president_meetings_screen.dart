import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../shared/native_agora_meeting_screen.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

// President creates, edits, ends, and joins shared video meetings.
class PresidentMeetingsScreen extends StatefulWidget {
  const PresidentMeetingsScreen({super.key});

  @override
  State<PresidentMeetingsScreen> createState() =>
      _PresidentMeetingsScreenState();
}

class _PresidentMeetingsScreenState extends State<PresidentMeetingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;

  Map<String, dynamic> get _data => MobileApiService.syncedData ?? {};
  bool get _canCreate =>
      MobileApiService.currentUser?['role']?.toString() == 'sk_president';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final meetings = _meetings();
    final upcoming = meetings.where((m) => m.isUpcoming).toList();
    final past = meetings.where((m) => m.isPast).toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: null,
        onItemSelected: _handleNavSelection,
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Meeting'),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'Video Meetings',
                subtitle: 'Create and join web meetings',
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Upcoming',
                        value: '${upcoming.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(label: 'Past', value: '${past.length}'),
                    ),
                  ],
                ),
              ),
              _MeetingSection(
                title: 'Upcoming Meetings',
                meetings: upcoming,
                emptyText: _canCreate
                    ? 'No upcoming meetings yet. Create one using the button below.'
                    : 'No upcoming meetings yet.',
                onJoin: _joinMeeting,
                onEdit: _canCreate ? (meeting) => _showCreateDialog(meeting) : null,
                onEnd: _canCreate ? _endMeeting : null,
              ),
              _MeetingSection(
                title: 'Past Meetings',
                meetings: past,
                emptyText: 'No past meetings yet.',
                onJoin: _joinMeeting,
              ),
            ],
          ),
        ),
      ),
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

  List<_MeetingItem> _meetings() {
    final rows = _data['meetings'] as List<dynamic>? ?? [];
    final meetings = rows
        .whereType<Map>()
        .map((row) => _MeetingItem.fromRow(Map<String, dynamic>.from(row)))
        .toList();
    meetings.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return meetings;
  }

  Future<void> _showCreateDialog([_MeetingItem? meeting]) async {
    final titleController = TextEditingController(text: meeting?.title ?? '');
    final agendaController = TextEditingController(text: meeting?.agenda ?? '');
    DateTime date = meeting?.scheduledAt ?? DateTime.now();
    TimeOfDay time = meeting == null
        ? TimeOfDay.now()
        : TimeOfDay.fromDateTime(meeting.scheduledAt);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(meeting == null ? 'Create Meeting' : 'Edit Meeting'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Meeting title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: agendaController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Agenda',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PickerTile(
                    icon: Icons.calendar_today,
                    label: _dateLabel(date),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => date = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _PickerTile(
                    icon: Icons.schedule,
                    label: time.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (picked != null) {
                        setDialogState(() => time = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                ),
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    _showMessage('Meeting title is required.');
                    return;
                  }
                  Navigator.pop(context);
                  if (meeting == null) {
                    await _createMeeting(
                      title: title,
                      agenda: agendaController.text.trim(),
                      date: date,
                      time: time,
                    );
                  } else {
                    await _updateMeeting(
                      meeting: meeting,
                      title: title,
                      agenda: agendaController.text.trim(),
                      date: date,
                      time: time,
                    );
                  }
                },
                child: Text(meeting == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    agendaController.dispose();
  }

  Future<void> _createMeeting({
    required String title,
    required String agenda,
    required DateTime date,
    required TimeOfDay time,
  }) async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.createMeeting(
        title: title,
        agenda: agenda.isEmpty ? null : agenda,
        meetingDate: date,
        meetingTime: TimeOfDayData(hour: time.hour, minute: time.minute),
      );
      if (mounted) _showMessage('Meeting scheduled successfully.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Saves edited meeting details to the shared web database.
  Future<void> _updateMeeting({
    required _MeetingItem meeting,
    required String title,
    required String agenda,
    required DateTime date,
    required TimeOfDay time,
  }) async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.updateMeeting(
        meetingId: meeting.id,
        title: title,
        agenda: agenda.isEmpty ? null : agenda,
        meetingDate: date,
        meetingTime: TimeOfDayData(hour: time.hour, minute: time.minute),
      );
      if (mounted) _showMessage('Meeting updated successfully.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinMeeting(_MeetingItem meeting) async {
    try {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NativeAgoraMeetingScreen(
              meetingId: meeting.id,
              title: meeting.title,
            ),
          ),
        );
      }
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    }
  }

  Future<void> _endMeeting(_MeetingItem meeting) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End meeting?'),
        content: Text('End "${meeting.title}" and move it to Past Meetings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            child: const Text('End Meeting'),
          ),
        ],
      ),
    );

    if (shouldEnd != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await MobileApiService.endMeeting(meeting.id);
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

class _MeetingSection extends StatelessWidget {
  final String title;
  final List<_MeetingItem> meetings;
  final String emptyText;
  final ValueChanged<_MeetingItem> onJoin;
  final ValueChanged<_MeetingItem>? onEdit;
  final ValueChanged<_MeetingItem>? onEnd;

  const _MeetingSection({
    required this.title,
    required this.meetings,
    required this.onJoin,
    this.onEdit,
    this.onEnd,
    this.emptyText = 'No meetings yet.',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (meetings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.lightText),
                  ),
                ),
              )
            else
              ...meetings.map(
                (meeting) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                child: _MeetingCard(
                    meeting: meeting,
                    onJoin: () => onJoin(meeting),
                    onEdit: onEdit == null ? null : () => onEdit!(meeting),
                    onEnd: onEnd == null ? null : () => onEnd!(meeting),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final _MeetingItem meeting;
  final VoidCallback onJoin;
  final VoidCallback? onEdit;
  final VoidCallback? onEnd;

  const _MeetingCard({
    required this.meeting,
    required this.onJoin,
    this.onEdit,
    this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGrayBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryRed,
                child: Text(
                  meeting.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meeting.displayDateTime,
                      style: const TextStyle(
                        color: AppColors.lightText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: meeting.statusLabel, active: meeting.isActive),
            ],
          ),
          if (meeting.agenda.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              meeting.agenda,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: meeting.canJoin ? onJoin : null,
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Join Meeting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (onEnd != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onEnd,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    side: const BorderSide(color: AppColors.primaryRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('End'),
                ),
              ],
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDFF8EA) : AppColors.softPink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF009E4D) : AppColors.primaryRed,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE2EA)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryRed),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEFF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MeetingItem {
  final int id;
  final String title;
  final String agenda;
  final String status;
  final String callUrl;
  final DateTime scheduledAt;

  const _MeetingItem({
    required this.id,
    required this.title,
    required this.agenda,
    required this.status,
    required this.callUrl,
    required this.scheduledAt,
  });

  factory _MeetingItem.fromRow(Map<String, dynamic> row) {
    final date = _text(row['meeting_date']);
    final time = _text(row['meeting_time']);
    final parsed = DateTime.tryParse(
      '$date ${time.isEmpty ? '00:00:00' : time}',
    );

    return _MeetingItem(
      id: _int(row['meeting_id']),
      title: _text(row['title']).isEmpty
          ? 'Untitled Meeting'
          : _text(row['title']),
      agenda: _text(row['agenda']),
      status: _text(row['status']).isEmpty
          ? 'scheduled'
          : _text(row['status']).toLowerCase(),
      callUrl: _text(row['call_url']),
      scheduledAt: parsed ?? DateTime.now(),
    );
  }

  bool get isActive {
    final now = DateTime.now();
    return status == 'scheduled' &&
        !scheduledAt.isAfter(now) &&
        scheduledAt.add(const Duration(hours: 1)).isAfter(now);
  }

  bool get isUpcoming =>
      !isPast && status != 'cancelled' && status != 'canceled';
  bool get isPast {
    final now = DateTime.now();
    final cancelled = status == 'cancelled' || status == 'canceled';
    final completed = status == 'completed' && !scheduledAt.isAfter(now);
    return cancelled ||
        completed ||
        scheduledAt.add(const Duration(hours: 1)).isBefore(now);
  }

  bool get canJoin => isUpcoming;

  String get statusLabel {
    if (status == 'cancelled' || status == 'canceled') {
      return 'Cancelled';
    }
    if (isPast) return 'Completed';
    if (isActive) return 'Ready';
    return 'Upcoming';
  }

  String get displayDateTime =>
      '${_dateLabel(scheduledAt)} ${_timeLabel(scheduledAt)}';

  String get initials {
    final words = title
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'MT';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

String _dateLabel(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
