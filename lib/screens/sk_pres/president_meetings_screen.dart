import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../shared/native_agora_meeting_screen.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

class PresidentMeetingsScreen extends StatefulWidget {
  const PresidentMeetingsScreen({super.key});

  @override
  State<PresidentMeetingsScreen> createState() => _PresidentMeetingsScreenState();
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
    if (MobileApiService.syncedData == null) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetings = _meetings();
    final active = meetings.where((m) => m.isActive).toList();
    final scheduled = meetings.where((m) => m.isScheduled).toList();
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
                    Expanded(child: _StatCard(label: 'Active', value: '${active.length}')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(label: 'Scheduled', value: '${scheduled.length}')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(label: 'Past', value: '${past.length}')),
                  ],
                ),
              ),
              _MeetingSection(
                title: 'Scheduled Meetings',
                meetings: scheduled,
                emptyText: _canCreate
                    ? 'No scheduled meetings yet. Create one using the button below.'
                    : 'No scheduled meetings yet.',
                onJoin: _joinMeeting,
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

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final agendaController = TextEditingController();
    DateTime date = DateTime.now();
    TimeOfDay time = TimeOfDay.now();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create Meeting'),
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
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRed),
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  Navigator.pop(context);
                  await _createMeeting(
                    title: title,
                    agenda: agendaController.text.trim(),
                    date: date,
                    time: time,
                  );
                },
                child: const Text('Create'),
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

  const _MeetingSection({
    required this.title,
    required this.meetings,
    required this.onJoin,
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
                  child: _MeetingCard(meeting: meeting, onJoin: () => onJoin(meeting)),
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

  const _MeetingCard({required this.meeting, required this.onJoin});

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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      style: const TextStyle(color: AppColors.lightText, fontSize: 12),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: meeting.canJoin ? onJoin : null,
              icon: const Icon(Icons.video_call_outlined),
              label: const Text('Join Meeting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
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

  const _PickerTile({required this.icon, required this.label, required this.onTap});

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
          Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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
    final parsed = DateTime.tryParse('$date ${time.isEmpty ? '00:00:00' : time}');

    return _MeetingItem(
      id: _int(row['meeting_id']),
      title: _text(row['title']).isEmpty ? 'Untitled Meeting' : _text(row['title']),
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

  bool get isScheduled =>
      status == 'scheduled' && scheduledAt.isAfter(DateTime.now());
  bool get isPast =>
      status != 'scheduled' ||
      (!isActive && !scheduledAt.isAfter(DateTime.now()));
  bool get canJoin => status == 'scheduled' && !isPast;

  String get statusLabel {
    if (status == 'completed') return 'Completed';
    if (status == 'cancelled') return 'Cancelled';
    if (isActive) return 'Ready';
    return 'Upcoming';
  }

  String get displayDateTime => '${_dateLabel(scheduledAt)} ${_timeLabel(scheduledAt)}';

  String get initials {
    final words = title.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
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
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
