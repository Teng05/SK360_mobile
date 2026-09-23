import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../shared/native_agora_meeting_screen.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

class PresidentMeetingsScreen extends StatefulWidget {
  const PresidentMeetingsScreen({super.key});

  @override
  State<PresidentMeetingsScreen> createState() =>
      _PresidentMeetingsScreenState();
}

class _PresidentMeetingsScreenState extends State<PresidentMeetingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  String? _loadError;

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
                title: 'Video Meetings',
                subtitle: 'Connect with your council',
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
                eyebrow: 'Council sessions',
                eyebrowIcon: Icons.videocam_outlined,
                title: 'Video Meetings',
                subtitle: 'Connect with your council, wherever they are.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: AppMetricGrid(
                  children: [
                    _StatCard(
                      label: 'Upcoming',
                      value: '${upcoming.length}',
                      icon: Icons.event_available_outlined,
                      color: AppColors.primaryRed,
                      caption: 'Scheduled sessions',
                    ),
                    _StatCard(
                      label: 'Past',
                      value: '${past.length}',
                      icon: Icons.history_rounded,
                      color: AppColors.muted,
                      caption: 'Completed or ended',
                    ),
                  ],
                ),
              ),
              if (_canCreate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: AppActionButton(
                    label: 'Create Meeting',
                    icon: Icons.video_call_outlined,
                    onPressed: _showCreateDialog,
                  ),
                ),
              const SizedBox(height: 22),
              _MeetingSection(
                title: 'Upcoming Meetings',
                meetings: upcoming,
                emptyText: _canCreate
                    ? 'No upcoming meetings yet. Create one using the button above.'
                    : 'No upcoming meetings yet.',
                onJoin: _joinMeeting,
                onEnd: _canCreate ? _endMeeting : null,
                onEdit: _canCreate ? _showCreateDialog : null,
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
    DateTime date = meeting?.scheduledAt ?? DateTime.now();
    TimeOfDay time = meeting == null
        ? TimeOfDay.now()
        : TimeOfDay.fromDateTime(meeting.scheduledAt);
    bool initialized = false;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => AppDialogForm(
        builder: (context, controllers) {
          final titleController = controllers[0];
          final agendaController = controllers[1];
          if (!initialized) {
            titleController.text = meeting?.title ?? '';
            agendaController.text = meeting?.agenda ?? '';
            initialized = true;
          }
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                icon: const AppIconTile(icon: Icons.video_call_outlined),
                title: Text(
                  meeting == null ? 'Create Meeting' : 'Edit Meeting',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Meeting title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: agendaController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Agenda'),
                      ),
                      const SizedBox(height: 12),
                      _PickerTile(
                        icon: Icons.calendar_today,
                        label: _dateLabel(date),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: date.isBefore(DateTime.now())
                                ? date
                                : DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                            lastDate:
                                date.isAfter(
                                  DateTime.now().add(const Duration(days: 365)),
                                )
                                ? date
                                : DateTime.now().add(const Duration(days: 365)),
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
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              _showMessage('Enter a meeting title.');
                              return;
                            }
                            setDialogState(() => isSubmitting = true);
                            final saved = await _saveMeeting(
                              meetingId: meeting?.id,
                              title: title,
                              agenda: agendaController.text.trim(),
                              date: date,
                              time: time,
                            );
                            if (saved) {
                              if (context.mounted) Navigator.pop(context);
                            } else if (context.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                          },
                    child: Text(
                      isSubmitting
                          ? 'Saving...'
                          : meeting == null
                          ? 'Create'
                          : 'Save Changes',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _saveMeeting({
    int? meetingId,
    required String title,
    required String agenda,
    required DateTime date,
    required TimeOfDay time,
  }) async {
    setState(() => _isLoading = true);
    try {
      final meetingTime = TimeOfDayData(hour: time.hour, minute: time.minute);
      if (meetingId == null) {
        await MobileApiService.createMeeting(
          title: title,
          agenda: agenda.isEmpty ? null : agenda,
          meetingDate: date,
          meetingTime: meetingTime,
        );
      } else {
        await MobileApiService.updateMeeting(
          meetingId: meetingId,
          title: title,
          agenda: agenda.isEmpty ? null : agenda,
          meetingDate: date,
          meetingTime: meetingTime,
        );
      }
      if (mounted) {
        _showMessage(
          meetingId == null
              ? 'Meeting scheduled successfully.'
              : 'Meeting updated.',
        );
      }
      return true;
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
      return false;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MeetingSection extends StatelessWidget {
  final String title;
  final List<_MeetingItem> meetings;
  final String emptyText;
  final ValueChanged<_MeetingItem> onJoin;
  final ValueChanged<_MeetingItem>? onEnd;
  final ValueChanged<_MeetingItem>? onEdit;

  const _MeetingSection({
    required this.title,
    required this.meetings,
    required this.onJoin,
    this.onEnd,
    this.onEdit,
    this.emptyText = 'No meetings yet.',
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = onEnd != null || title.startsWith('Upcoming');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeading(
            icon: upcoming ? Icons.event_available_outlined : Icons.history,
            title: title,
            action: AppStatusBadge(
              label: '${meetings.length}',
              color: upcoming ? AppColors.primaryRed : AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          if (meetings.isEmpty)
            _Panel(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.lightText),
                  ),
                ),
              ),
            )
          else
            ...meetings.map(
              (meeting) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MeetingCard(
                  meeting: meeting,
                  onJoin: () => onJoin(meeting),
                  onEnd: onEnd == null ? null : () => onEnd!(meeting),
                  onEdit: onEdit == null || meeting.status != 'scheduled'
                      ? null
                      : () => onEdit!(meeting),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final _MeetingItem meeting;
  final VoidCallback onJoin;
  final VoidCallback? onEnd;
  final VoidCallback? onEdit;

  const _MeetingCard({
    required this.meeting,
    required this.onJoin,
    this.onEnd,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = meeting.isActive
        ? AppColors.success
        : meeting.isPast
        ? AppColors.muted.withValues(alpha: .45)
        : AppColors.primaryRed;
    final dateColor = meeting.isPast ? AppColors.muted : AppColors.primaryRed;
    return AppAccentCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDateBlock(date: meeting.scheduledAt, color: dateColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(
                      label: meeting.statusLabel,
                      active: meeting.isActive,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      meeting.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppMeta(
                      icon: Icons.schedule_rounded,
                      label: meeting.displayDateTime,
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit meeting',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          if (meeting.agenda.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: AppDecorations.inset(radius: 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Agenda  ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGray,
                      ),
                    ),
                    TextSpan(text: meeting.agenda),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _ActionRow(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: meeting.canJoin ? onJoin : null,
                  icon: const Icon(Icons.videocam_outlined, size: 20),
                  label: const Text('Join Meeting'),
                  style:
                      AppCardButtonStyle.primary(
                        color: meeting.isActive
                            ? AppColors.success
                            : AppColors.primaryRed,
                      ).copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(48, 46)),
                      ),
                ),
              ),
              if (onEnd != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onEnd,
                  style:
                      AppCardButtonStyle.secondary(
                        color: AppColors.actionRed,
                      ).copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(48, 46)),
                      ),
                  child: const Text('End'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Keeps Join and End side by side on phones, stacking only when cramped.
class _ActionRow extends StatelessWidget {
  final List<Widget> children;
  const _ActionRow({required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18) {
        return Row(children: children);
      }
      return AppAdaptiveRow(children: children);
    },
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.success
        : label == 'Upcoming'
        ? AppColors.info
        : AppColors.muted;
    return AppStatusBadge(label: label, color: color, dot: true);
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
      borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.field,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String caption;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatistic(
      label: label,
      value: value,
      icon: icon,
      color: color,
      caption: caption,
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
